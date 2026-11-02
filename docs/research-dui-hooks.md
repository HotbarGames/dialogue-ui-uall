# Dialogue UI 1.0.6: where every visible string is set, and where to swap in Ukrainian

Read-only research, 2026-11-02. Source: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\DialogueUI\` (written `DUI/` below). Bridge: `DialogueUI_UALL/Core.lua`.
Every claim has a file:line. When something can only be settled in game, the report says so.

`UA(kind, english[, extra])` is the owner's lookup (it returns nil when there is no translation). The kind names used below (`"gossip"`, `"option"`, `"quest_title"`, `"ui"`, `"objective"`, `"npc"`, `"item"`) are placeholders only.

---

## 0. Facts that decide the whole design

**0.1 Mixins are copied when a frame is created. Wrapping a global mixin later only reaches frames created after the wrap.**
- `DUIQuestFrame` is declared with `mixin="DUIDialogBaseMixin"` and `<OnLoad method="OnLoad"/>` (DUI/Code/Dialogue/DialogueUI.xml:365, 575-576). Its OnLoad runs while DialogueUI.xml is parsed, which is before our addon loads (our TOC has `## Dependencies: DialogueUI, UALLF`, DialogueUI_UALL.toc:5). So the frame already holds its own copies of every `DUIDialogBaseMixin` method. **Wrapping `DUIDialogBaseMixin.X` now does nothing; wrap `DUIQuestFrame.X`.** Every internal call goes through `self:X(...)` (for example DialogueUI.lua:1293, 1552, 1556, 1563, 2367 `self[handler](self, ...)`, 3480). The only direct mixin reference is `DUIDialogBaseMixin.OnHide` (DialogueUI.lua:2431), which is irrelevant here. No other DUI file calls these methods (grep: only DialogueUI.lua and UITemplates.lua).
- During OnLoad, `UpdateFrameSize()` (DialogueUI.lua:499) creates `AcceptButton` and `ExitButton` from `DUIDialogOptionButtonTemplate` (DialogueUI.lua:220-226, 618-659). Both already carry copies of `DUIDialogOptionButtonMixin`. **Wrap them per instance:** `DUIQuestFrame.AcceptButton` and `DUIQuestFrame.ExitButton`.
- All pools are lazy: `ObjectPoolMixin:Acquire` creates only when needed (DUI/API.lua:280-292). The pools are instance fields of the global frame: `optionButtonPool`, `questTypeFramePool`, `itemButtonPool`, `smallItemButtonPool`, `fontStringPool`, `hotkeyFramePool`, `iconFramePool` (DialogueUI.lua:389, 413, 449, 462, 475, 483, 497). Their template mixins (`DUIDialogOptionButtonMixin`, `DUIDialogQuestTypeFrameMixin`, `DUIDialogItemButtonMixin`, `DUIDialogSmallItemButtonMixin`) are globals (UITemplates.lua:236, 2290, 1378, 1960). **Wrap the global mixin at our file load, and also run `pool:ProcessAllObjects(wrap)` (API.lua:320-324) for anything created before that.**
- `DUIQuestFrame.FrontFrame.QuestPortrait` is an XML child with `mixin="DUIDialogQuestPortraitMixin"` (DialogueUI.xml:471). It exists already, so wrap it per instance.

**0.2 `L[...]` strings are snapshots taken at load, and `L` is private.** Example: `L["Accept"] = ACCEPT or "Accpet"` (DUI/Locales/enUS.lua:17) is evaluated once, when the locale file loads. Changing `_G.ACCEPT` later has no effect, and an outside addon cannot reach `L`. On an enUS client, though, each `L` value equals the Blizzard global (or literal) next to it in enUS.lua. So **match on the English text, built from the same expressions** (§6 table), or on `button.type` (§4).

**0.3 Captured upvalues mean the Blizzard getters cannot be swapped.** These are all captured when DUI loads: `GetQuestTitle = GetTitleText` (DialogueUI.lua:59), `GetGossipText = API.GetGossipText` (DialogueUI.lua:49), which is `C_GossipInfo.GetText` (API.lua:1245, 1254); `GetQuestText` reading `GetQuestText`/`GetProgressText`/`GetRewardText`/`GetGreetingText` (API.lua:1240-1262); `ItemTextGetText` (Book/BookUI.lua:34). Replacing those globals would also taint Blizzard code. **So inject where the text enters layout,** not at the source.

**0.4 Fonts: Cyrillic should render with no font hook (check once in game).** DUI's font objects inherit font families that have a `russian` member set to DUI's own `frizqt___cyr.ttf`: `DUIFontFamily_Serif_18/16/12/12_Outline/10/10_Outline/8` and `Trajan_18` (DUI/Fonts.xml:23, 46, 69, 92, 115, 138, 161, 184). On an enUS client, `FontUtil` calls `SetFont(frizqt__.ttf)` on every `DUIFont_*` object (FontUtil.lua:19, 125-128, 315-329, 357-368).
- My cmap parse: `frizqt__.ttf` has **0** Cyrillic code points. `frizqt___cyr.ttf` has all of ҐґЄєІіЇїЖжЩщЮюЯя, plus full ASCII and all of Latin‑1 except U+00B7.
- UALLF's author observed in game that `SetFont` on a font *family* replaces only the main member, and Cyrillic is still drawn by the family's Cyrillic member (UALLF/Fonts.lua:79-84, "перевірено в грі 03.10.2026").
- So Ukrainian in the title, subheaders, buttons and paragraphs should be drawn by `frizqt___cyr.ttf`, and measured with the real glyphs.
- **Verify once in game.** If squares appear, add a `hooksecurefunc(_G[name], "SetFont", ...)` that swaps `frizqt__.ttf` for `frizqt___cyr.ttf` on the `FONT_OBJECT_HEIGHT` names (FontUtil.lua:44-79).
- `DUIFont_ItemCount` uses ARIALN.ttf directly (Fonts.xml:228), which has Cyrillic (94 code points).

**0.5 Re-renders: every hook must be idempotent.** `OnSettingsChanged` reruns the whole handler, `self[self.handler](self)` (DialogueUI.lua:3472-3485). It fires on theme load (DialogueUI.lua:591), font size (3514, 3524), frame size (3565), RP names (3583), several settings (3588-3596), input device (3625) and the translator button click (TranslatorPublic.lua:157). The handler also reruns on `QUEST_ITEM_UPDATE` (DialogueUI.lua:2595), and the greeting reruns on `QUEST_LOG_UPDATE` (DialogueUI.lua:2621). Every pre-hook below translates the fresh English argument on each call, so each rerun produces the same result. Post-hooks start from text DUI itself has just reset.

**0.6 Wrapper pattern used throughout** (each element has its own pcall and falls back to English on its own, and the original is never called inside the pcall, so DUI's own errors still surface as normal):

```lua
local originals = setmetatable({}, { __mode = "k" })   -- obj -> { key = orig }

local function Wrap(obj, key, makeWrapper)            -- per-instance or per-mixin
    if type(obj) ~= "table" or type(obj[key]) ~= "function" then return false end
    local o = originals[obj] or {}
    if o[key] then return true end                    -- already wrapped (idempotent install)
    o[key] = obj[key]; originals[obj] = o
    obj[key] = makeWrapper(o[key])
    return true
end

local function Try(fn, ...)                            -- nil on any error
    local ok, res = pcall(fn, ...)
    if ok then return res end
end

local function StripColor(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|c[nN][%w_]+:", ""):gsub("|r", ""))
end
```
(Every `text == ""` and every comparison stays under pcall, as `Text()`/`Same()` already do in Core.lua:33-43, because Midnight-engine clients can return "secret" strings.)

---

## 1. Window header: quest title, and the extra title paragraph

**Source.** `GetTitleText()` is captured as `GetQuestTitle` (DialogueUI.lua:59).

**Setter.** `DUIDialogBaseMixin:UpdateQuestTitle(method)` (DialogueUI.lua:784-846). It calls `title:SetText(text)` (798), then shrinks the font: `DUIFont_Quest_Title_18` → `_16` if more than 1 line → `DUIFont_Quest_Paragraph` (795-807). The font string is `DUIQuestFrame.FrontFrame.Header.Title` (DialogueUI.xml:424). Its anchors are LEFT x=53 and RIGHT (DialogueUI.xml:425-428), and DialogueUI.lua:758/762 resets the RIGHT anchor when the warband icon is shown.

**Layout effects.**
- The return value is a constant, `6 * FRAME_SIZE_MULTIPLIER` (845), so the body offset does not depend on the title.
- Header widgets are anchored `BOTTOMLEFT` to `Title.TOPLEFT` (QuestHeaderWidget.lua:104, anchor set at DialogueUI.lua:311), so they follow a height change automatically.
- **So a post-hook that sets new text and reruns the shrink logic needs no other re-layout.**

**Callers.** `HandleQuestDetail` (1552), `HandleQuestProgress` (1692) and `HandleQuestComplete` (1849). Each calls `UpdateQuestTitle` and then `FormatQuestText` (1556, 1695, 1852).

**The extra title paragraph.** `FormatQuestText` (1787-1811) calls `API.GetQuestTextExternal(questID, method)` (1794). If `title and text1` (1795), it inserts `self:InsertParagraph(offsetY, title, "DUIFont_Quest_MultiLanguage")` (1796), then adds `PARAGRAPH_SPACING` (1798) and then `FormatDualParagraph` (1799).
- `GetQuestTextExternal` returns `data.title` for every method (TranslatorPublic.lua:118-128).
- `IsQuestTranslationAvailable` needs `data.title` to be a non-empty string (TranslatorPublic.lua:133-137), and it decides whether the translator button is shown (166-196).
- **So a translator cannot keep the button while suppressing the paragraph:** any non-empty title inserts one. A title of `" "` still inserts a blank line, because `InsertText` keeps the font string's height (1029-1030), plus spacing.
- The only call of `InsertParagraph` with `"DUIFont_Quest_MultiLanguage"` in DUI is line 1796. The other callers are 1577 and 1596, with no font argument. **So a narrow instance wrapper on `InsertParagraph` can drop exactly that paragraph.** If it returns `offsetY` unchanged, the remaining `+PARAGRAPH_SPACING` (1798) gives exactly the untranslated path's spacing (1806).

**Translator on/off.** The translator button's left-click flips the private `ENABLE_TRANSLATION` (TranslatorPublic.lua:155). When it is off, `GetQuestTextExternal` returns before calling our getter (TranslatorPublic.lua:114-118). When it is on, it **always** calls the getter, whatever the data. So "our getter was called inside `FormatQuestText`" means "translation is on". `IsQuestTranslationAvailable` also calls the getter, but earlier: from `ViewingQuest` (TranslatorPublic.lua:169), which `UpdateQuestTitle` triggers at DialogueUI.lua:841, before `FormatQuestText`.

**Hook design.** Wrap `FormatQuestText` (instance) and set a flag while it runs. Inside it, wrap `InsertParagraph` to skip the MultiLanguage title. After it, set the header to Ukrainian only if the getter was asked (that is, translation is on).

```lua
local qt = { active = false, asked = false }

-- in SafeGetUALLFQuest (Core.lua:302), first line, before the per-frame cache:
--   if qt.active then qt.asked = true end

local function ShowOriginal()
    local db = _G.DialogueUI_DB
    return type(db) == "table" and db.TranslatorShowOriginalText == true  -- GetDBBool semantics, Initialization.lua:255-258
end

local function SetHeaderTitle(frame, text)
    local title = frame.FrontFrame.Header.Title
    title:SetFontObject("DUIFont_Quest_Title_18")           -- same steps as DialogueUI.lua:795-807
    title:SetJustifyV("BOTTOM"); title:SetJustifyH("LEFT")
    title:SetText(text)
    if title:GetNumLines() > 1 then
        title:SetFontObject("DUIFont_Quest_Title_16")
        if title:GetNumLines() > 1 then title:SetFontObject("DUIFont_Quest_Paragraph") end
    end
end

Wrap(DUIQuestFrame, "InsertParagraph", function(orig)
    return function(self, offsetY, text, fontObject, ...)
        if fontObject == "DUIFont_Quest_MultiLanguage" and qt.active and qt.uaTitle and not ShowOriginal() then
            return offsetY                                   -- drop the duplicate title line
        end
        return orig(self, offsetY, text, fontObject, ...)
    end
end)

Wrap(DUIQuestFrame, "FormatQuestText", function(orig)
    return function(self, offsetY, method, ...)
        qt.active, qt.asked = true, false
        qt.uaTitle = Try(function()
            local en = GetTitleText(); return Text(en) and UA("quest_title", en, self.questID)
        end)
        local r1, r2 = orig(self, offsetY, method, ...)     -- no pcall: DUI errors stay visible
        qt.active = false
        if qt.asked and qt.uaTitle then Try(SetHeaderTitle, self, qt.uaTitle) end
        qt.uaTitle = nil
        return r1, r2
    end
end)
```
- Note the order: `UA()` runs *before* `orig`, so the InsertParagraph wrapper knows whether a Ukrainian header will exist. The header is changed only *after* `orig`, once `qt.asked` is known.
- If `UA` has no title, nothing changes: the header stays English and the paragraph is kept.
- When the player turns on "show original" (right-click), Dialogue UI's own layout returns: English body, Ukrainian under it, Ukrainian title paragraph. The header is still Ukrainian in that mode (owner's choice: also require `not ShowOriginal()` before `SetHeaderTitle` to keep the header English then).

**Gaps.** If `GetQuestText(method)` is empty, `FormatQuestText` skips its whole body (1790), our getter is never asked, and the header stays English (rare: quests with no completion text).

**TTS.** `GetTTSTextFromFontStrings` reads `Header.Title:GetText()` (3396), but only for `UseFontStringForTTS` (TranslatorPublic.lua:45-60), which only Platine1AddOns.lua:16 turns on. Default TTS uses `GetQuestTitle()` (2876), which is English.

**Risk: Medium.** The flag spans one synchronous call, so it is safe. The header could end up Ukrainian next to an English body only if the getter was asked but had no body (`ForWindow` returns nil, Core.lua:237-242). That is acceptable, and in fact intended: "whole window Ukrainian".

---

## 2. NPC name

- **The quest header never shows the NPC name as text.** `UseQuestLayout(true)` sets only the portrait texture (DialogueUI.lua:743-744). For gossip, greeting and gossip-confirm, `UseQuestLayout(false)` hides the header (772; called at 1280, 1888, 2049).
- **`ConcatenateNPCName`** (DialogueUI.lua:1119-1128) runs only when the `ShowNPCNameOnPage` setting is on and `UnitExists("npc")`. It prefixes `UnitName("npc")..": "` to the gossip text (1292), the greeting (1895) and the quest body (1788).
  - Gossip and greeting go to `FormatParagraph` (§3). The §3 substring replacement keeps the `"Name: "` prefix and can also translate it: if `UA("npc", UnitName("npc"))` is non-nil, replace the prefix `name..": "` when the text starts with it (plain `find(..., 1, true) == 1`).
  - With a translation, the quest body's prefixed English goes into `FormatDualParagraph` as `text1` (1799), which is shown only when "show original" is on (1082-1088). The Ukrainian `text1` from the translator has no prefix. Without a translation it goes to `FormatParagraph(..., flag 3)` (1807).
- **Quest-giver portrait name.** `GetQuestPortraitGiver()` 3rd return (1582) → `QuestPortrait:SetPortrait(id, name)` (1592) → `DUIDialogQuestPortraitMixin:SetName` (UITemplates.lua:2533-2539), which runs SetText, then switches to `DUIFont_Constant_8` if truncated. The frame was created from XML at load (DialogueUI.xml:471), so wrap it per instance (pre-hook, measured after):

```lua
Wrap(DUIQuestFrame.FrontFrame.QuestPortrait, "SetName", function(orig)
    return function(self, name, ...)
        local ua = Text(name) and Try(UA, "npc", name)
        return orig(self, ua or name, ...)
    end
end)
```
**Risk: Low.**

---

## 3. Gossip text, quest-greeting text, gossip-confirm text

**Sources.**
- Gossip: `C_GossipInfo.GetText` through the upvalue `GetGossipText` (DialogueUI.lua:49, 1286). Then `self.hintText.."\n\n"` is prepended if set (1287-1290; the hint is a gossip option's name, from the "Show answer." button, UITemplates.lua:414 and 131-134). Then `ConcatenateNPCName` (1292).
- Greeting: `GetGreetingText` through `GetQuestText("Greeting")` (API.lua:1244, 1249-1262; DialogueUI.lua:1895).
- Gossip confirm: the `GOSSIP_CONFIRM` event's text (2631), colour-adjusted by `ThemeUtil:AdjustTextColor` (2053), which rewrites red/blue codes (ThemeUtil.lua:14-35).
- With the RP-name setting, `GetGossipText`/`GetQuestText` are replaced by modified versions (DialogueUI.lua:3575-3583, API.lua:1524-1538).

**Setter.** `DUIDialogBaseMixin:FormatParagraph(offsetY, text, ttsFlag)` (1039-1067). It splits with `API.SplitParagraph` (on control characters, API.lua:454-468), then per paragraph does SetText → `GetHeight` → advances `offsetY` (1050-1051). **So a pre-hook on `text` means the Ukrainian is measured.**

**Every `FormatParagraph` caller and its flag** (`addon.TTSFlags`: Gossip=0, QuestText=1, QuestTitle=2, QuestObjective=3, TTS.lua:27-33):

| line | text | flag |
|---|---|---|
| 1293 | gossip text (+hint, +NPC name) | 0 |
| 1896 | greeting text (+NPC name) | 0 |
| 2054 | GOSSIP_CONFIRM warning | 0 |
| 1571 | `GetObjectiveText()` when no translated objective | 3 |
| 1807 | quest body when not translated | 3 |
| 1112, 1115 | `FormatDualParagraph` fallback (`text1`) | nil |

(1569 passes a 4th argument to `FormatDualParagraph`, which that function ignores, DialogueUI.lua:1069.) **So flag 0 means exactly gossip, greeting and confirm.**

**How to tell which one.**
- `self.handler` is `"HandleGossip"` or `"HandleQuestGreeting"` (set at 2365 before the handler runs).
- `HandleGossipConfirm` is not dispatched through `ShowUI`, so `handler` stays `"HandleGossip"` there. Do not rely on `self.requireGossipConfirm`: it is set at 2046 and cleared only in `HideGossipConfirm` (2084).
- Instead, for `HandleGossip`, look for `C_GossipInfo.GetText()` inside `text`. If it is not found, treat the whole text as confirm text.

```lua
local function ReplacePlain(text, en, ua)           -- first plain occurrence
    local s, e = text:find(en, 1, true)
    if not s then return nil end
    return text:sub(1, s - 1) .. ua .. text:sub(e + 1)
end

Wrap(DUIQuestFrame, "FormatParagraph", function(orig)
    return function(self, offsetY, text, ttsFlag, ...)
        if ttsFlag == 0 and Text(text) then
            local ua = Try(function()
                local en, kind
                if self.handler == "HandleQuestGreeting" then
                    en, kind = GetGreetingText(), "greeting"
                else
                    en, kind = C_GossipInfo.GetText(), "gossip"
                end
                local out
                if Text(en) then
                    local tr = UA(kind, en)
                    if tr then out = ReplacePlain(text, en, tr) end
                end
                if not out and self.handler == "HandleGossip" then   -- GOSSIP_CONFIRM popup text
                    local tr = UA("gossip_confirm", StripColor(text))
                    if tr then out = tr end
                end
                if out then                                    -- optional: NPC name prefix
                    local name = UnitName("npc")
                    local trn = Text(name) and UA("npc", name)
                    if trn and out:find(name .. ": ", 1, true) == 1 then
                        out = trn .. ": " .. out:sub(#name + 3)
                    end
                end
                return out
            end)
            if ua then text = ua end
        end
        return orig(self, offsetY, text, ttsFlag, ...)
    end
end)
```
- If RP names are on, the modified text no longer contains `en`, so it falls back to English (Low).
- The hint prefix stays English unless the hint is also looked up; it is an option name, so `UA("option", self.hintText)` would work.

**Side effects.**
- TTS reads APIs, not these font strings: `GetContentForTTS` → `GetGossipText()` / `GetQuestText("Greeting")` (2879-2897). Font strings are read only for `fs.isTranslation` (2851-2869, set only by `FormatDualParagraph` 1103) or under Platine (3379-3400). So TTS speaks English gossip. Under Platine it would read the Ukrainian (fine).
- CopyText uses the raw APIs on purpose (2916-2918, 2926-2950), so it stays English.
- The gossip history (`keepGossipHistory`, 1257-1268) keeps earlier, already-Ukrainian font strings. Fine.

**Risk: Low-Medium** (only the substring match can fail, and that falls back to English).

---

## 4. Gossip reply buttons (and every other option button)

**Source.** `C_GossipInfo.GetOptions()` (DialogueUI.lua:51, 1225), sorted (1227).

**`DUIDialogOptionButtonMixin:SetGossip(data, hotkey)`** (UITemplates.lua:362-403):
- name = `GossipDataProvider:GetOverrideName(id) or data.name` (365). Override names are LFR dungeon names (GossipData_LFRQueue.lua:243) and zone names (GossipData_Teleport.lua:164), already localized by Blizzard APIs.
- `ThemeUtil:AdjustTextColor(name)` (369) rewrites colour codes.
- The icon is chosen **from the English name** (`GetGossipIcon(data.icon, name, id)`, 382, with name keys "Inn", "Gossip Red"…, GossipData_Icon.lua:7-44, 61-64). **So translate after `SetGossip` has chosen the icon, not by changing `data.name` up front.**
- Hotkey prefix: `name = hotkey..". "..name` (393-395). The hotkey comes from `KeyboardControl:SetIndexedAction` (DialogueUI.lua:1349); with no hotkey there is no prefix (1351).
- Then `self:SetButtonText(name, false)` (398).

**Funnel.** `SetButtonText(name, bigPadding)` does `self.Name:SetText(name); self:Layout(bigPadding)` (UITemplates.lua:357-360). `Layout` sets the Name width from `baseWidth`/`rightFrameWidth`/hotkey/icon (796-820), then **`Name:GetHeight()` → `SetHeight`** (822-824). **Every** option-button text goes through it: gossip (398), hint (423), quest entries (482, 524), Goodbye (597), Decline (615), Accept/Quest Log Full (633/640), Quest Accepted (656), OK (669), Continue/Incomplete (699/706), Complete (721/727), Cancel (745, 784), confirm-gossip Accept (760/772).
- `self.type`, `self.questID` and `self.gossipOptionID` are always set before that call (363, 389, 413, 520, 550/561/573/582, 593, 605, 622, 647, 665, 676, 713, 736, 753, 781).
- Re-layout without new text (`Layout(true)` at DialogueUI.lua:3345/3349/3616) only re-measures, so translated text survives.

**Hook (pre-hook, Low risk).** Wrap `SetButtonText` on the global mixin (for future pool buttons), on the existing pool objects, and on the two footer buttons:

```lua
local UI = {}      -- §6: English L value -> Ukrainian (fallbacks when UA("ui") has none)

local function TranslateButton(self, name)
    local t = self.type
    if t == "gossip" then
        local prefix, rest = name:match("^(%d+%. )(.*)$")   -- UITemplates.lua:394
        rest = rest or name
        local plain = StripColor(rest)
        local ua = UA("option", plain) or UI[plain]           -- UI[] covers "Show answer."
        if not ua then return nil end
        local lead = rest:match("^(|c%x%x%x%x%x%x%x%x)")      -- keep a whole-string colour
        if lead and rest:sub(-2) == "|r" then ua = lead .. ua .. "|r" end
        return (prefix or "") .. ua
    elseif t == "availableQuest" or t == "activeQuest" then
        return UA("quest_title", name, self.questID)          -- questID set at UITemplates.lua:520
    else                                                      -- footer/action buttons
        return UA("ui", name) or UI[name]
    end
end

local function WrapSetButtonText(obj)
    return Wrap(obj, "SetButtonText", function(orig)
        return function(self, name, bigPadding, ...)
            local ua = Text(name) and Try(TranslateButton, self, name)
            return orig(self, ua or name, bigPadding, ...)
        end
    end)
end

WrapSetButtonText(DUIDialogOptionButtonMixin)                  -- before the first pool button exists
WrapSetButtonText(DUIQuestFrame.AcceptButton)                  -- created in OnLoad (DialogueUI.lua:620)
WrapSetButtonText(DUIQuestFrame.ExitButton)                    -- DialogueUI.lua:645
DUIQuestFrame.optionButtonPool:ProcessAllObjects(WrapSetButtonText)
-- re-apply the current footer labels once (they were set in English at load):
-- not needed: every handler calls SetButton* again before showing.
```

**Height notes.**
- The footer buttons' height was measured in English at load to place the footer divider and scroll frame (DialogueUI.lua:229-235). If a Ukrainian label wraps at half width (`halfFrameWidth`, 202), the button grows past the divider. Keep the Ukrainian action labels short ("Прийняти", "Відмовитися", "Далі", "Завершити", "Скасувати", "До побачення").
- Gossip and quest buttons in the scroll body re-measure their own height, and the body sums the heights (1496-1499), so long text is safe there.

**Hotkey labels.** `HotkeyFrame.KeyName` shows key names (`"Esc"` from UITemplates.lua:596/614/744/783, `PRIMARY` → the bound key, 1069-1071, icons for SPACE/pads, 978-1015). These are keyboard names; leave them.

**Risk: Low.**

---

## 5. Quest entries in gossip and quest-greeting lists

**Gossip.** Entries come from `C_GossipInfo.GetAvailableQuests()` / `GetActiveQuests()` (DialogueUI.lua:52-53, 1223-1224) as `questInfo.title`, `questInfo.questID` (1374-1402). They go through `SetAvailableQuest` / `SetActiveQuest` (1414/1416) → `SetQuest` (UITemplates.lua:512-537), which sets `self.questID = questInfo.questID` (520) and then `SetButtonText(questInfo.title, true)` (524). **So the §4 hook gets the questID.**

**Greeting.**
- Available: `GetAvailableTitle(i)` (1908) and `questID` = 5th return of `API.GetAvailableQuestInfo(i)` (1909).
- Active: `GetActiveTitle(i)` (1944) and `GetActiveQuestID(i)` (1945).
- If the client lacks these functions, DUI's stubs return **0** (API.lua:1083-1097), and the greeting code stores `questID or 0` (1924). **So in greetings, look up by English title when the ID is 0.**
- Then `SetGreetingAvailableQuest` / `SetGreetingActiveQuest` (1981/1983) → the same `SetQuest`.

**Quest-type tag** (right side). `SetQuestTypeText` (UITemplates.lua:448-492) runs from `OnQuestLoaded` (530-536). Its text is one of:
- `L["Quest Type Trivial"]` = "Trivial" (enUS.lua:12)
- `L["Quest Type Repeatable"]` = "Repeatable" (enUS.lua:11)
- `L["Quest Frequency Daily"]` = `DAILY or "Daily"` (enUS.lua:8)
- `L["Quest Frequency Weekly"]` = `WEEKLY or "Weekly"` (enUS.lua:9)
- or `API.SecondsToTime` (461). That branch can never run: `not questInfo.frequency == 3` is always false (459).

It goes through `questTypeFrame:SetRightText(typeText)` (476) → `SetNameAndIcon` → SetText + `SetWidth(GetContentWidth())` (UITemplates.lua:2305-2332, 2359-2365). That width is read back (479-481) and the title is re-laid out (482). **So a pre-hook on `SetRightText` is measured.** The frames come from a lazy pool (DialogueUI.lua:465-475) with the global mixin:

```lua
local function WrapTypeFrame(obj)
    return Wrap(obj, "SetRightText", function(orig)
        return function(self, text, ...)
            local ua = Text(text) and Try(function() return UA("ui", text) or UI[text] end)
            return orig(self, ua or text, ...)
        end
    end)
end
WrapTypeFrame(DUIDialogQuestTypeFrameMixin)
DUIQuestFrame.questTypeFramePool:ProcessAllObjects(WrapTypeFrame)
```

**Other list visuals.** `UpdateGossipQuests` on `QUEST_LOG_UPDATE` only changes icons and art (DialogueUI.lua:2021-2040, UITemplates.lua:494-510). The warband icon has no text (UITemplates.lua:941-949).

**Risk: Low.**

---

## 6. Section headers and action buttons

**Section headers.** All go through `DUIDialogBaseMixin:AcquireAndSetSubHeader(text)` (DialogueUI.lua:701-721). It does SetText (707), then **`GetWrappedWidth()` sizes the background** (709-716). So an instance pre-hook is measured. Callers and the enUS L values:

| call | L key → enUS value (Locales/enUS.lua) |
|---|---|
| 1563, 1755 | `"Quest Objectives"` = `OBJECTIVES_LABEL or "Objectives"` (:25) |
| 1612, 1864 | `"Reward"` = `REWARD or "Reward"` (:26) / `"Rewards"` = `REWARDS or "Rewards"` (:27) |
| 1712, 2060 | `"Costs"` = literal `"Costs"` (:38) |
| 1739 | `"Requirements"` = `REQUIREMENTS or "Requirements"` (:33) |

There is no "Quest Complete" subheader in the main window. `L["Quest Complete Alert"]` is used only by QuestFlyout.lua:304 and as auto-complete flyout text (DialogueUI.lua:1832).

**Action buttons** (via §4 `SetButtonText`), with their enUS values:
- `"Accept"` = `ACCEPT or "Accpet"` (:17)
- `"Continue"` = `CONTINUE` (:18)
- `"Complete Quest"` = `COMPLETE or "Complete"` (:19)
- `"Incomplete"` = `INCOMPLETE` (:20)
- `"Cancel"` = `CANCEL` (:21)
- `"Goodbye"` = `GOODBYE` (:22)
- `"Decline"` = `DECLINE` (:23)
- `"OK"` = `"OK"` (:24)
- `"Quest Accepted"` (:44)
- `"Quest Log Full"` = `"Quest Log Is Full"` (:45)
- hint `"Show Answer"` = `"Show answer."` (:368)

Matching on the English text is better than matching on `type`: type `"accept"` covers both "Accept" and "Quest Log Is Full" (UITemplates.lua:629-641), and type `"continue"` covers both Continue and Incomplete (679-707).

**Building the table without `addon.L`.** At our file load, use the same expressions, so the keys equal DUI's L values on enUS:

```lua
UI[_G.ACCEPT or "Accpet"]          = "Прийняти"
UI[_G.CONTINUE or "Continue"]      = "Далі"
UI[_G.COMPLETE or "Complete"]      = "Завершити"
UI[_G.INCOMPLETE or "Incomplete"]  = "Не виконано"
UI[_G.CANCEL or "Cancel"]          = "Скасувати"
UI[_G.GOODBYE or "Goodbye"]        = "До побачення"
UI[_G.DECLINE or "Decline"]        = "Відмовитися"
UI["OK"]                           = "Гаразд"
UI["Quest Accepted"]               = "Завдання прийнято"
UI["Quest Log Is Full"]            = "Журнал завдань повний"
UI["Show answer."]                 = "Показати відповідь."
UI[_G.OBJECTIVES_LABEL or "Objectives"]   = "Цілі"
UI[_G.REWARD or "Reward"]          = "Нагорода"
UI[_G.REWARDS or "Rewards"]        = "Нагороди"
UI["Costs"]                        = "Вартість"
UI[_G.REQUIREMENTS or "Requirements"]     = "Потрібно"
UI["Trivial"]                      = "Легке"         -- quest-type tags (§5)
UI["Repeatable"]                   = "Повторюване"
UI[_G.DAILY or "Daily"]            = "Щоденне"
UI[_G.WEEKLY or "Weekly"]          = "Щотижневе"
```
(The Ukrainian wording is the owner's call, and UALLF's UI.lua may already have these. Prefer `UA("ui", en)` and use this table as the fallback. Do not write into `_G.ACCEPT` and the like: Blizzard's QuestFrame reads them too.)

On a ruRU/deDE client the L values are that locale's strings, so the lookups miss and the text stays as DUI shows it. That is a safe fallback.

```lua
Wrap(DUIQuestFrame, "AcquireAndSetSubHeader", function(orig)
    return function(self, text, ...)
        local ua = Text(text) and Try(function() return UA("ui", text) or UI[text] end)
        return orig(self, ua or text, ...)
    end
end)
```
**Risk: Low.**

---

## 7. Reward-area labels and the Progress screen

**"Choose / you will be able to choose".** `FormatRewards` (DialogueUI.lua:3059-3174) calls `self:InsertText(offsetY, REWARD_CHOOSE)` (3093) or `REWARD_CHOICES` (3096). These are **Blizzard globals read at call time**: DialogueUI.lua has no local copy (grep). `InsertText` (1024-1032) does SetText → `GetHeight` → offset, so an instance pre-hook is measured.

**"You will also receive:" and spell headers.** These are `data.header` entries. `REWARD_ITEMS` is read at call time (QuestRewards.lua:235, 265). The spell-bucket headers (`REWARD_SPELL`, `REWARD_ABILITY`, `REWARD_FOLLOWER`…) are captured at file load (QuestRewards.lua:47-83). `FormatRewards` renders them with `AcquireLeftFontString()` + `SetText(data.header)` and places them on a 1-row grid cell (3141-3148; row height `smallItemButtonHeight = 15`, 3069/3073). So a header that wraps to 2 lines overlaps the row below; that is equally true for English. **Hook:** a pre-hook on instance `FormatRewards` that rewrites `data.header` in the list. The list is built fresh for every call (QuestRewards.lua:159, `rewardList = {}`), but copy each entry to be safe.

**Money / XP.** XP is numbers only (UITemplates.lua:2063-2077). Money goes through `API.GenerateMoneyText` with `L["Format Copper Amount"]` / `L["Symbol Copper"]`… (API.lua:1663-1679), using coin letters. Leave both.

**Item / currency / spell names.** Item names come from `GetQuestItemInfo` (UITemplates.lua:1634). `self.itemID` is set (1640) before `SetItemName(name, quality)` (1643). `SetItemName` does SetText → `FitToName` (1540-1553), so a pre-hook on the global `DUIDialogItemButtonMixin.SetItemName` (lazy pool, DialogueUI.lua:434-449) with `UA("item", name, self.itemID)` is measured. When the item isn't cached yet the name is empty, `RequestInfo` runs (1541-1545), and a later refresh calls `SetItem` again (1512-1538). Spells: `SetRewardspell(spellID, icon, name)` (1807). Title/war-mode/honor/follower labels use `L[...]` (1853, 1866, 1884, 1911). **Medium risk** (async item data), and optional.

**Progress screen.**
- The "required items" header is `L["Requirements"]` (1739, §6). Costs: `L["Costs"]` (1712).
- Required items and currencies are item buttons (1726-1748, `SetRequiredItem`/`SetRequiredCurrency`).
- **Objective progress lines.** `API.GetQuestLogProgress(questID)` (1752) builds `"- "..GetQuestLogLeaderBoard(i, logIndex)` joined with `"\n"` (API.lua:1046-1067). It is drawn by `self:InsertText(offsetY, objcetiveProgress)` (1758) under the `L["Quest Objectives"]` subheader (1755).
  - **Existing DUI bug:** the return value of that `InsertText` is discarded (1758), so `SetScrollRange(offsetY)` (1772) leaves out these lines. Longer Ukrainian lines make an existing clipping risk worse, because the scroll range will not include them. The cause is DUI's, not ours.
- **Quest objectives on the Detail screen** (`GetObjectiveText`) are already translated by the translator (`data.objective` → `FormatDualParagraph`, 1568-1569). When there is no translation they go to `FormatParagraph(…, 3)` (1571). Optional: in the §3 wrapper, `ttsFlag == 3 and self.handler == "HandleQuestDetail" and text == GetObjectiveText()` → `UA("objectives", text, self.questID)`.

**One `InsertText` wrapper covers 1758, `REWARD_CHOOSE`/`REWARD_CHOICES`, and everything routed through `InsertParagraph`:** suggested players `L["Format Suggested Players"]` = `QUEST_SUGGESTED_GROUP_NUM` (enUS.lua:70; DialogueUI.lua:1576-1577), `questPortraitText` (1595-1596), and the translator title paragraph (1796, already handled in §1).

```lua
Wrap(DUIQuestFrame, "InsertText", function(orig)
    return function(self, offsetY, text, fontObject, ...)
        if Text(text) then
            local ua = Try(function()
                if text == _G.REWARD_CHOOSE or text == _G.REWARD_CHOICES then
                    return UA("ui", text) or UI[text]
                end
                if self.handler == "HandleQuestProgress" and text:sub(1, 2) == "- " then
                    local out, any = {}, false
                    for line in text:gmatch("[^\n]+") do          -- lines built at API.lua:1058/1060
                        local body = line:match("^%- (.*)$")
                        local tr = body and UA("objective", body, self.questID)
                        out[#out + 1] = tr and ("- " .. tr) or line
                        any = any or tr ~= nil
                    end
                    if any then return table.concat(out, "\n") end
                end
            end)
            if ua then text = ua end
        end
        return orig(self, offsetY, text, fontObject, ...)
    end
end)

Wrap(DUIQuestFrame, "FormatRewards", function(orig)
    return function(self, offsetY, rewardList, ...)
        local list = rewardList
        Try(function()
            local copy, changed = {}, false
            for i, d in ipairs(rewardList) do
                if type(d) == "table" and Text(d.header) then
                    local tr = UA("ui", d.header) or UI[d.header]
                    if tr then
                        local c = {}; for k, v in pairs(d) do c[k] = v end
                        c.header = tr; d = c; changed = true
                    end
                end
                copy[i] = d
            end
            if changed then list = copy end
        end)
        return orig(self, offsetY, list, ...)
    end
end)
```
(The list copy keeps the isRewardChoices group table, `data.numChoices` and `chooseItems`, unchanged by reference, DialogueUI.lua:3079-3090.)

**Risk: Medium** (the objective-line format depends on what UALLF can match; anything it doesn't match stays English line by line).

---

## 8. Other English in the quest/gossip window

| text | where | source | reachable hook | priority |
|---|---|---|---|---|
| Header widgets: campaign name, quest tag, time left, "Account quest", quest-line name | QuestHeaderWidget.lua:112-140, 354-410, 452-479; text via `ButtonMixin:SetText` → `ButtonText:SetText` (285-287), sized by `Layout` (227-277) | `C_CampaignInfo`, `API.GetQuestTagNameIcon`, `ACCOUNT_QUEST_LABEL`, `API.SecondsToTime`, quest-line API (DialogueUI.lua:811-834) | The pool is private, but the widgets are children of `DUIQuestFrame.FrontFrame.Header` (`CreateFrame(... HeaderWidgetManger.parent ...)`, :36, parent set at :24-28 via DialogueUI.lua:310), and `ButtonMixin` is mixed into each instance (:37). Post-hook in the §1 `FormatQuestText` wrapper: for each `{Header:GetChildren()}` with `.ButtonText`, set the text, then `child:Layout()`. Chained anchors (:101-107) follow by themselves. Async `RequestQuestData` can add widgets later (:184-214); those stay English. Mostly retail data. | low |
| Quest-giver portrait name | §2 | `GetQuestPortraitGiver` | §2 | low |
| GOSSIP_CONFIRM text | §3 | event | §3 | med |
| Gossip-code input label | DialogueUI.xml:148 `text="ENTER_CODE"` | Blizzard global | `DUIQuestFrame.InputBox.Label` (the InputBox is a child of the global frame, DialogueUI.lua:250, 2093-2097); set once, so `SetText` at install | low |
| Quest-type tags | §5 | L | §5 | med |
| Suggested players / portrait text | §7 | `QUEST_SUGGESTED_GROUP_NUM` / quest data | §7 `InsertText` | low |
| Tooltips: "This quest is accepted automatically by the game." (enUS.lua:46; UITemplates.lua:309), "- You have %s" (enUS.lua:68; UITemplates.lua:260), warband alert (DialogueUI.lua:316) | SharedTooltip | L | out of scope (tooltips); possible later | — |
| Hotkey names ("Esc", "1") | §4 | key names | leave | — |
| Outside the window: top-right alerts "Format Quest Accepted/Completed" (AlertFrame.lua:117/121), auto-complete flyout `L["Quest Complete Alert"]` (QuestFlyout.lua:304), "Auto Select" chat line (DialogueUI.lua:1171/1186/1195) | — | L | not covered | — |

The header `Subtitle` is cleared every time (DialogueUI.lua:792-793), so it shows nothing.

---

## (a) Re-renders and idempotency

**Full rebuilds.** `OnSettingsChanged` (3472-3485) and its triggers are listed in §0.5. The handlers also rerun from `UpdateRewards` (2595), `QUEST_LOG_UPDATE` → `HandleQuestGreeting` (2621), and `HideGossipConfirm` → `HandleGossip` (2087).

**Partial updates through `SetButtonText`:**
- `HandleQuestAccepted` → `SetButtonAlreadyOnQuest` / `SetButtonCloseAutoAcceptQuest` (1651-1654)
- `SelectRewardChoice` → `SetButtonCompleteQuest` (2133-2134)
- the button-lock callbacks (UITemplates.lua:686-690, 764-768)
- `OnQuestLoaded` → `SetQuestTypeText` (530-536)

All of these pass fresh English through the wrapped functions, so they are idempotent by construction.

**`LoadTheme` (511-592)** changes only fonts and art (UITemplates.lua:896-904, 864-894), then calls `OnSettingsChanged`.

**The only post-hooks** (header title, header widgets) start from text DUI has just reset (`UpdateQuestTitle` 798, `ReleaseAllWidgets` 809).

**Install the wrappers once** (the `originals[obj][key]` guard). Never re-wrap a mixin per render.

## (b) TTS and CopyText

- **CopyText:** always the raw Blizzard APIs ("Use unmodified APIs", 2916-2918; 2926-3030), so it stays English.
- **TTS default:** APIs as well (2873-2898), so English. It reads font strings only on two paths:
  - (i) translator available + `TTSReadTranslation` + translator on: only `fs.isTranslation` strings (2847-2872), which are already the Ukrainian body;
  - (ii) Platine's `UseFontStringForTTS` (TranslatorPublic.lua:45-60, Platine1AddOns.lua:16): `fs.ttsFlag` strings and `Header.Title` (3379-3400). That would read our Ukrainian, which is fine.
- `GetContentForTTS` adds the speaker name from `API.GetCurrentNPCInfo` (2904-2907), in English.

## (c) Book UI (bonus, ranked separately)

**Window.** `DUIBookFrame` is global (Book/BookUI.xml:90, mixin `DUIBookUIMixin`, BookUI.lua:551).

**Where the text comes from.**
- Page text: `ItemTextGetText`, captured at BookUI.lua:34, read in `Cache:CacheCurrentPage` (277-296) on `ITEM_TEXT_READY` (1921-1932).
- `Cache` (18) and `Formatter` are file-local.
- Title: `ItemTextGetItem()` (181) → `MainFrame.Header:SetTitle(title)` (376). That is `HeaderFrameMixin:SetTitle` → auto-scaling SetText (BookUI_Component.lua:99-130), mixed into `DUIBookFrame.Header` by `InitHeader` (BookUI_Component.lua:346-361) during `DUIBookFrame:Init()` (BookUI.lua:1326-1330). Init runs on the first `ITEM_TEXT_BEGIN` (1884-1887).

**Paragraph pipeline.**
1. `Formatter:FormatText` → `FormatParagraph`/`FormatHTML` split into `Cache.activeData.formattedContent` (1081-1113, 384).
2. Heights are measured by `Formatter:GetTextHeight`, which uses a private `UtilityFontString:SetText(text)` → `GetHeight()` (1067-1079). That font string is created in OnLoad on `DUIBookFrame.ContentFrame` (1310-1315).
3. Display: `DUIBookFrame.ScrollFrame:SetObjectData` → `obj:SetText(data.text)` (1338-1352), an instance function defined in `Init`.

**Injection options.**
- **(1) Title: easy.** After Init (`hooksecurefunc(DUIBookFrame, "Init", ...)` or on `ITEM_TEXT_BEGIN`), wrap `DUIBookFrame.Header.SetTitle` as a pre-hook with `UA("item", title)` (UALLF translates book titles with its item base, UALLF/BookHooks.lua:9-10). Low risk.
- **(2) Body: hard.** Measurement and display use two different font strings, both reachable only as unnamed regions of `DUIBookFrame.ContentFrame`. The Utility one is the first font string created there (1310). Pool font strings are created lazily (1406-1423). A working design:
  - on `ITEM_TEXT_READY`, read `ItemTextGetText()` ourselves and get UALLF's page translation (UALLF stores whole pages and matches on normalized text, BookHooks.lua:15-37);
  - split both the English and the Ukrainian with DUI's rule `gmatch("[%C]+")`, dropping `" "` (API.lua:459-463), and if the paragraph counts match, build a map from English paragraph to Ukrainian;
  - `hooksecurefunc` `SetText` on every ContentFrame font string (rescan on each event) and immediately re-`SetText` the mapped Ukrainian under a re-entrancy guard. The `GetHeight()` in `GetTextHeight` then measures the Ukrainian.
  - Paragraph-count mismatches and HTML books (`FormatHTML`, 1126+) stay English.
  - **Risk: High.** Recommend only after everything above ships.

---

## Final ranked implementation plan

| # | Step | Hook (reachable from outside) | Re-layout | Risk |
|---|---|---|---|---|
| 0 | Check in game that Ukrainian renders in DUI's fonts (family `russian` member, §0.4). If squares appear, add a `SetFont` post-hook that swaps to `frizqt___cyr.ttf` | — | — | Low |
| 1 | Option buttons: gossip replies, quest list titles, Accept/Decline/Continue/Complete/Cancel/Goodbye/OK, "Show answer." | wrap `SetButtonText` on `DUIDialogOptionButtonMixin` + `DUIQuestFrame.AcceptButton/ExitButton` + `optionButtonPool:ProcessAllObjects` | none (pre-hook; `Layout` measures) | Low |
| 2 | Section headers | wrap instance `DUIQuestFrame.AcquireAndSetSubHeader` | none | Low |
| 3 | Gossip / greeting / confirm text (+NPC-name prefix) | wrap instance `DUIQuestFrame.FormatParagraph`, flag 0 only, plain-substring replace | none | Low-Med |
| 4 | Header quest title + drop the duplicate title paragraph, following the translator toggle | wrap instance `FormatQuestText` (flag + post-set header with the font shrink) and `InsertParagraph` (skip the MultiLanguage title); one-line flag in `SafeGetUALLFQuest` | header shrink only (copy of 795-807) | Med |
| 5 | Quest-type tags | wrap `DUIDialogQuestTypeFrameMixin.SetRightText` + `questTypeFramePool:ProcessAllObjects` | none (width read after) | Low |
| 6 | Reward labels (`REWARD_CHOOSE`/`CHOICES`, `REWARD_ITEMS` headers), Progress objective lines, suggested players | wrap instance `InsertText` and `FormatRewards` | none | Med |
| 7 | Quest-giver portrait name | wrap `DUIQuestFrame.FrontFrame.QuestPortrait.SetName` | none (truncation check after) | Low |
| 8 | Item / spell reward names (optional, if UALLF has them) | wrap `DUIDialogItemButtonMixin.SetItemName` (+ `itemButtonPool`) | none (`FitToName` after) | Med |
| 9 | Header widgets, input-box label | post-hook in step 4 over `Header:GetChildren()` + `child:Layout()`; one-time `InputBox.Label:SetText` | `Layout()` per widget | Low (low value on Forever) |
| B | Book UI title / body (bonus) | `DUIBookFrame.Header.SetTitle` after Init / SetText hooks on ContentFrame font strings | body: measurement must see Ukrainian | Low / High |

**General rules for all steps.**
- Install at our file load. DUI is a hard dependency, so `DUIQuestFrame` and its two footer buttons already exist, and no pool object exists until the first interaction.
- Each element gets its own `pcall` around *our* lookup only.
- Never call the original inside a pcall, and never write into DUI's argument tables (copy them).
- Never write Blizzard globals.

Update `Core.lua`'s header comment ("Limits", Core.lua:16-19) when this ships.
