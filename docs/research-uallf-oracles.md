# UALLF oracles: getting UALL Forever's Ukrainian string for an English string from a third addon

Read-only research, 2026-11-02. Sources (all line numbers checked in the installed files):
- UALLF 1.0.10: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\UALLF\` (paths below are relative to it)
- Dialogue UI 1.0.6: `...\AddOns\DialogueUI\`
- Blizzard UI source: Gethe/wow-ui-source, branch `forever` (1.60.1.70532), `Interface/AddOns/` (shortened to `BZ/`)
- Our bridge: `DialogueUI_UALL/Core.lua`

## 0. Facts every oracle depends on

- **No API.** UALLF writes no globals except `UALLFSettingsDB` (UALLF.toc:7) and the slash command (QuestHooks.lua:202-203). Everything else is in the private `ns` table.
- **Load order.** Our toc has `## Dependencies: DialogueUI, UALLF` (DialogueUI_UALL.toc:6), so UALLF's files and its PLAYER_LOGIN frames run before ours. All the hooks used below exist after UALLF's PLAYER_LOGIN handlers have run (details per kind).
- **Gates.** `ns.Active(key) = ns.IsEnabled(key) and not ns.SuppressTranslation()` (Settings.lua:299-301).
  - `IsEnabled` = master switch `enabled` plus that key (Settings.lua:261-266).
  - `SuppressTranslation` is true while `ns.reverting` is set, when `enabled` is off, and in normal mode while the original key is held. Default key is SHIFT (Settings.lua:30, 269-275); in reverse mode it is never true (Settings.lua:290-296).
  - `ns.ActiveShown(key)` additionally requires `not ns.ShowOriginal()` (Settings.lua:307-309). In reverse mode that means "only while the key is held".
- **Remember / Shift.** Every widget replacement calls `ns.Remember(fs, en, ua, key)`, which stores `ns.replacements[fs] = {en, ua, key}` (Core.lua:93-99).
  - `ns.ToggleOriginal` (on MODIFIER_STATE_CHANGED, Core.lua:254-260) visits every remembered widget whose own `IsShown()` flag is set. It swaps the text only when the current text equals `pair.ua` or `pair.en` (Core.lua:179-209).
  - So after a probe restores the widget to some third text, Shift does nothing to it.
  - Reverse mode: `Remember` also installs a SetText hook that writes `pair.en` back at once (Core.lua:76-98). A probe that reads `GetText()` afterwards then sees English. The bridge's capture-hook approach (Core.lua:107-121 of the bridge) still sees the Ukrainian line. The bridge returns nil in reverse mode anyway (bridge Core.lua:78-88).
- **No flicker.** Every probe below is synchronous: set the English text, read the result, restore, all in one Lua call. WoW draws only after the script returns, so even a visible widget would never show the probe text. All widgets proposed here are also hidden while Dialogue UI is active:
  - Dialogue UI calls `QuestFrame:UnregisterAllEvents()` (DialogueUI/Code/Core.lua:415). QuestFrame is `hidden="true"` in XML (BZ/Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:42), so QuestFrame and all its panels stay hidden.
  - It unregisters GossipFrame's GOSSIP_SHOW, GOSSIP_CLOSED and QUEST_LOG_UPDATE (DialogueUI/Code/Core.lua:408-410), so GossipFrame never shows and `GossipFrame:Update()` never runs.
- **UALLF's own event frames are separate.** Dialogue UI does not touch them. GossipHooks' frame (GossipHooks.lua:292-304) still gets GOSSIP_SHOW and QUEST_GREETING. But `InstallGossipText` already ran at PLAYER_LOGIN: `pcall(InstallGossipText)` comes before the PLAYER_LOGIN `return` (GossipHooks.lua:297-298), and GossipFrame exists at login.
- **Flavors.** The Forever copy holds both a Mainline and a Vanilla QuestFrame. UALLF says Forever runs the Mainline quest window (QuestHooks.lua:3-5).
  - Every global used below exists in both `BZ/Blizzard_UIPanels_Game/Mainline/QuestFrame.xml` and `.../Vanilla/QuestFrame.xml` (GreetingText, CurrentQuestsText: Mainline 250/256, Vanilla 339/345).
  - GossipFrame is in Mainline/GossipFrame.xml:34 and Shared/GossipFrameShared.lua.
  - Retail Mainline loads the same Mainline/Shared files. I did not check this against a separate Retail source copy, so Retail is "expected, unverified". UALLF itself declares Retail 120100 (UALLF.toc:1), but its data is Forever's.

---

## 1. UI labels and buttons (`ns.UI_LABELS`, then `ns.uiStrings`)

**Oracle:** QuestHooks `PinLabel` → `LabelText` (QuestHooks.lua:76-92).
- It is installed at PLAYER_LOGIN by `ns.PinQuestPanelLabels` (QuestHooks.lua:187-190). It is a `hooksecurefunc(obj,"SetText")` on, among others, `CurrentQuestsText`, `AvailableQuestsText`, `QuestFrameAcceptButton`, `QuestFrameGreetingGoodbyeButton`… (QuestHooks.lua:115-121).
- `LabelText` translates **any** string written to the widget: `ns.UI_LABELS[current] or ns.uiStrings[current]` (QuestHooks.lua:80). It does not check `IsShown`. It skips empty and Cyrillic text (QuestHooks.lua:79).
- Lookup order: UI_LABELS wins. So "Complete" gives "Виконано", not uiStrings' "Завершено"; "Required Money:" gives "Потрібні гроші:"; "Completed Quests" gives "Завершені завдання". That is exactly what UALLF shows on Blizzard's quest window.

**Best widget:** `_G.CurrentQuestsText`, a FontString in the hidden QuestFrameGreetingPanel.
- Its text is the XML constant CURRENT_QUESTS (QuestFrame.xml:256). Blizzard's Lua only recolours it (QuestFrame.lua:334).
- Do not use `QuestInfo*` labels such as `QuestInfoRequiredMoneyText` or `QuestInfoSpellObjectiveLearnLabel`. Those are shared with the quest map's details view and can be on screen.

**Recipe**
```lua
-- after PLAYER_LOGIN; never from inside a UALLF hook (labelBusy re-entrancy guard, QuestHooks.lua:77/83-85)
local function UALabel(en)
    local fs = _G.CurrentQuestsText
    if not (fs and fs.SetText) then return nil end
    local ua = CaptureVia(fs, en)          -- bridge-style: our SetText post-hook records the first text ~= en
    pcall(fs.SetText, fs, CURRENT_QUESTS)  -- restore with the ENGLISH original: UALLF re-translates it and
                                           -- re-Remembers the correct pair, so Shift keeps working on it
    return ua
end
```
- Flags: `labelBusy` is module-local (QuestHooks.lua:75). A call made while UALLF itself is inside `LabelText` returns nothing.
- `ns.reverting` (during ToggleOriginal) suppresses translation (Settings.lua:292).

**Gate:** `quests.ui` (default true, Settings.lua:54) plus `enabled` (Settings.lua:27), and the original key not held (normal mode).

**Side effects**
- `ns.Remember(CurrentQuestsText, en, ua, "quests.ui")` (QuestHooks.lua:82). Restoring with CURRENT_QUESTS overwrites this pair with the correct one, leaving nothing behind.
- UALLF also writes CurrentQuestsText on QUEST_GREETING (GossipHooks.lua:259-262, 301-303). That is harmless, because the probe is synchronous.

**Forever/Retail:** the widget is in both QuestFrame.xml variants.

**Failure mode:** no translation, gate off, or UALLF missing → nothing is captured → nil (show English). UALLF wraps its hook in pcall (QuestHooks.lua:90).

**Not an oracle:** `GossipFrame.GreetingPanel.GoodbyeButton` is translated only once, at install, with `ns.uiStrings` (GossipHooks.lua:217-226). It is not pinned.

---

## 2. NPC gossip greeting, quest greeting and reply options (`ns.ChatLookup`)

**Lookup itself:** `ns.ChatLookup = Lookup` (ChatHooks.lua:73-91).
1. Exact `ns.chatLines[AposNorm(text)]`. AposNorm turns curly apostrophes into straight ones (ChatHooks.lua:31-33).
2. Otherwise `ns.chatPatterns` buckets: the first 4 characters, then `""` (ChatHooks.lua:77-86).
3. Then `ns.Localize(ua)` (ChatHooks.lua:87). Localize expands `$N $C $R $B $G…; $p(..) {class}` in Ukrainian for the reader (Core.lua:377-414).
- It has a one-entry cache (ChatHooks.lua:71, 74, 88). It has no gate of its own.

**Text the server or client already filled in (names) is matched.** Patterns capture the inserted words (Chat.lua:2-4, e.g. Chat.lua:10716-10720) and `FromPattern` puts them back (ChatHooks.lua:41-69):
- The captured `$N` is inserted as is.
- When the NPC addresses the reader (`got.N == UnitName("player")`, or no N), `$C`/`$R` stay tokens, and Localize gives the Ukrainian class or race with the right case.
- Otherwise the game's words are kept (ChatHooks.lua:62-67).
- chatLines keys exist in both the `\n` and the `$B` form (Chat.lua:9-10), so client-side `$B` → newline also matches.

**Oracle A (primary, the gossip gate):** GossipHooks `PinText` on `_G.GreetingText` (GossipHooks.lua:142-150).
- It is installed in `InstallGossipText` (GossipHooks.lua:215), which runs at PLAYER_LOGIN (GossipHooks.lua:297).
- The hook calls `GossipTextUA`: `ns.ChatLookup(GetText())`, then `Remember(obj, text, ua, "gossip")`, then `SetText(ua)` (GossipHooks.lua:129-139). It does not check `IsShown`.
- GreetingText is the quest-greeting FontString in the hidden QuestFrameGreetingPanel (QuestFrame.xml:250). Blizzard writes it only in its greeting OnShow (QuestFrame.lua:332), which Dialogue UI suppresses. Dialogue UI never references it (no grep hits in DialogueUI).

```lua
local function UAGossip(en)              -- greeting text, quest greeting text, or a reply option's optionInfo.name
    local fs = _G.GreetingText
    if not (fs and fs.SetText) then return nil end
    local before = fs:GetText()
    local ua = CaptureVia(fs, en)
    pcall(fs.SetText, fs, before or "")  -- panel never shown under Dialogue UI; any pair left in ns.replacements
                                         -- needs current == ua/en, so Shift stays a no-op
    return ua
end
```
- Pass the raw `optionInfo.name`, not the button text. Blizzard prefixes quest and movie options with `GOSSIP_OPTION_PREPEND` (GossipFrameShared.lua:71-82), and that prefixed text is not a chatLines key.
- Flags: `textBusy` is shared with the NPC-title pin (GossipHooks.lua:127, 131, 136-138, 184).

**Gate:** `gossip` (default true, Settings.lua:68) plus `enabled`, and the key not held.

**Side effects:** one `ns.replacements[GreetingText]` entry (key "gossip"). Harmless, as explained above.

**Forever/Retail:** GreetingText is in both QuestFrame.xml variants (Mainline 250, Vanilla 339).

**Failure mode:** no line or pattern → nil.

**Do not use the gossip rows.** `GossipFrame.GreetingPanel` rows and the measuring frames (`greetingTextFrame`, `titleOptionButton`) are created in `GossipFrameSharedMixin:Update` (GossipFrameShared.lua:240-251). Under Dialogue UI that never runs, so UALLF's `PinRow`/`PinMeasuring` (GossipHooks.lua:153-176) have nothing to pin.

**Oracle B (fallback, no widget, but the chat gate):** `ChatFrameUtil.ProcessMessageEventFilters(chatFrame, event, ...)` is public (BZ/Blizzard_ChatFrameBase/Shared/ChatFrameFilters.lua:212-215).
- The filter list itself cannot be read. It sits in a local `SecureTypes.CreateSecureMap()` behind upvalues (ChatFrameFilters.lua:76-110, 177). `GetMessageEventFilters()` returns only the registry object with Add/Remove/ProcessFilters (198-200). No `ChatFrame_GetMessageEventFilters` alias exists (Deprecated_ChatFrame.lua:51, 76 alias only Add/Remove).
- But ProcessFilters runs every filter registered for the event and returns the transformed arguments (ChatFrameFilters.lua:138-171).
```lua
local ok, discard, ua = pcall(ChatFrameUtil.ProcessMessageEventFilters, DEFAULT_CHAT_FRAME,
                              "CHAT_MSG_MONSTER_SAY", en, npcName or "")
-- UALLF Filter returns false, ua, sender, ... (ChatHooks.lua:93-102); ua == nil or == en → no translation
```
- Gate: `chat.npc` with **ActiveShown** (ChatHooks.lua:94; Settings.lua:74), not `gossip`.
- Side effects:
  - UALLF's diagnostic counters and its "missing" list grow (ChatHooks.lua:97, 103-106).
  - Every other addon's MONSTER_SAY filter also runs. In this install only UALLF registers chat filters (grep over AddOns: UALLF/ChatHooks.lua, UALLF/SystemHooks.lua).
  - Another addon's filter could change the text before UALLF sees it.
- Same `ns.ChatLookup`, so the same wording.

---

## 3. Quest titles for quests an NPC lists (not the one that is open)

UALLF's own gossip list uses `ns.GetQuest(button:GetID()).title` (GossipHooks.lua:56-63; GetQuest = `ns.quests[id]`, Core.lua:287-290). Those buttons never exist under Dialogue UI (see kind 2). The QuestFrame greeting pool (GossipHooks.lua:236-283) is suppressed too. Usable paths:

**Oracle A (by questID, primary):** TrackerHooks `LogTooltipUA`, an EventRegistry callback on `"QuestMapLogTitleButton.OnEnter"` (TrackerHooks.lua:295-334). It is registered at file load and is not tied to the tracker setting.
- It requires `GameTooltip:GetOwner() == button` (TrackerHooks.lua:298).
- If line 1 is non-empty and not Cyrillic, it replaces it with `ns.Localize(ns.GetQuest(questID).title)` (TrackerHooks.lua:308-309). The English text on line 1 does not matter.
- Bonus: lines `"- …"` get `ns.TranslateQuestLine(text, questID)` (objective lines, TrackerHooks.lua:310-312). The first line after a `" "` line gets `quest.objectives` (TrackerHooks.lua:315-317). Any other line that is a `ns.uiStrings` key is translated (TrackerHooks.lua:313-314).
- Blizzard triggers this event only from QuestMapFrame.lua:2307. Its only Blizzard listener is Blizzard_PTRFeedback (PTR client). Dialogue UI's listener is dev-only (DialogueUI/API.lua:3464-3467, 3524).
```lua
local owner = CreateFrame("Frame")       -- our private owner
local function UAQuestTitleByID(questID, enTitle)
    local tip = GameTooltip
    if tip:IsShown() then return nil end -- don't steal a tooltip the player is reading (or accept it, see risk)
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:SetText(enTitle or "?")          -- line 1 placeholder
    EventRegistry:TriggerEvent("QuestMapLogTitleButton.OnEnter", owner, questID)
    local ua = GameTooltipTextLeft1:GetText()
    tip:Hide()
    if not ua or ua == (enTitle or "?") then return nil end
    return ua
end
```
- Gate: `quests.log` (default true, Settings.lua:48).
- Side effects:
  - `Remember(GameTooltipTextLeft1, …, "quests.log")` (TrackerHooks.lua:320). It is cleared by UALLF's own `OnTooltipCleared` hook, `ns.ForgetTooltip` (Core.lua:220-243), on the next SetOwner or clear.
  - `tip:Show()` if anything changed (TrackerHooks.lua:326).
  - Other addons' GameTooltip OnShow/OnHide/OnSizeChanged hooks fire. UALLF's minimap hooks are gated by `OverMinimap()` (MinimapHooks.lua:136-190).
- Risk:
  - It hides any tooltip that is showing. At GOSSIP_SHOW the NPC's mouseover tooltip is often up, so probe only when the tooltip is hidden, or accept losing it.
  - Firing a Blizzard EventRegistry event from addon code runs the listeners in tainted context. No secure listener exists in this source.
  - `C_QuestLog.IsComplete(questID)` is called for non-log quests (TrackerHooks.lua:300); it is harmless.

**Oracle B (by English title):** TrackerHooks `MapQuestTooltipUA` on `"TaskPOI.TooltipShown"` (TrackerHooks.lua:347-393).
- When `questID` is not a number: `ns.questTitles[plain or text]`, with a `"[lvl] "` prefix and colour kept via TitleInDecorated (TrackerHooks.lua:352, 362-365, 147-152).
- When it is a number: `ns.GetQuest(questID).title` (TrackerHooks.lua:359-361).
- Lines 2+ get `ns.uiStrings` (TrackerHooks.lua:372-373).
- Same tooltip recipe, with `EventRegistry:TriggerEvent("TaskPOI.TooltipShown", owner, nil)`. Blizzard fires it only from WorldMapFrame.lua:185; only PTRFeedback listens.
- Gate: `quests.mappins` (default true, Settings.lua:57). Same side effects and risk as A (key "quests.mappins").

**Oracle C (by English, no tooltip):** StorageHooks `Pin` on the mail and bag font strings (StorageHooks.lua:45-79), e.g. `_G.OpenMailSubject` (BZ/Blizzard_MailFrame/MailFrame.xml:919).
- `Lookup = uiStrings or itemNames or npcNames or questTitles` (StorageHooks.lua:20-23). A quest title that equals an item, NPC or UI string returns that translation instead.
- No IsShown check (StorageHooks.lua:25-43). Installed on PLAYER_LOGIN and ADDON_LOADED (StorageHooks.lua:81-85), so check that `_G.OpenMailSubject` exists.
- Gate: `interface.storage` (default true, Settings.lua:193).
- Side effect: `Remember(…, "interface.storage")`. It flickers only if the open-mail frame is on screen (it isn't during a gossip).

**Not usable:**
- `QuestProgressTitleText`/`QuestInfoTitleHeader` (the bridge's quest probe) read only `GetQuestID()` or the log's selected quest (QuestHooks.lua:15-24).
- Minimap tooltips need the mouse over the minimap (MinimapHooks.lua:136-190).
- The SystemHooks chat filter translates titles only inside a matching `ns.sysFormats` message, e.g. a full "Quest accepted: …" line (SystemHooks.lua:52-77, 40-43), so you would have to strip the Ukrainian frame text.

**Data note:** `ns.questTitles` has 3294 entries and `ns.quests` 4389 (Quests.lua:8525, 8527). By-ID covers more quests.

---

## 4. NPC names (`ns.npcNames`)

**Oracle:** GossipHooks `PinNpcTitle` on `QuestFrame:GetTitleText()` and `GossipFrame:GetTitleText()` (GossipHooks.lua:179-196). Both are installed at PLAYER_LOGIN (GossipHooks.lua:211, 216).
- The hook does `ns.npcNames[text]`, an exact match, then `Remember(self, text, ua, "gossip")` and `SetText` (GossipHooks.lua:183-193). It does not check IsShown and does not split "Name <Subtitle>".
- `GetTitleText()` = `self.TitleContainer.TitleText` (BZ/Blizzard_SharedXML/PortraitFrame.lua:4-6). Both frames inherit ButtonFrameTemplate (QuestFrame.xml:42; GossipFrame.xml:34).
```lua
local function UANpc(en)
    local fs = QuestFrame and QuestFrame.GetTitleText and QuestFrame:GetTitleText()
    if not fs then return nil end
    local before = fs:GetText()
    local ua = CaptureVia(fs, en)
    pcall(fs.SetText, fs, before or "")
    return ua
end
```
- Gate: `gossip` (default true, Settings.lua:68), the same gate UALLF uses for the NPC window title.
  - The tooltip and target-frame names use `world.npcNames` instead (NpcHooks.lua:22-24; Settings.lua:91). Its NpcHooks `TranslateNameFS` also handles "Name <Subtitle>" (NpcHooks.lua:58-79), but it is bound to tooltip and unit frames.
- Flags: shared `textBusy` (GossipHooks.lua:184, 189-191).
- Side effects: one Remember entry (key "gossip") on a hidden title. QuestFrame is never shown under Dialogue UI; Blizzard sets its title only in QuestFrame.lua:117.
- Forever/Retail: in both.
- Failure: not in npcNames → nil.
- Alternative: StorageHooks Lookup also covers npcNames, after uiStrings and itemNames (StorageHooks.lua:20-23; gate `interface.storage`).

---

## 5. Label table (English → what UALLF puts on Blizzard's widgets)

The "LabelText result" column is what the kind-1 oracle returns: UI_LABELS (Core.lua:263-285) first, then uiStrings (UI.lua `ns.uiStrings`, starts at UI.lua:7). Each key below occurs once in uiStrings.

| English | uiStrings (UI.lua line) | UI_LABELS (Core.lua line) | LabelText result |
|---|---|---|---|
| Accept | Прийняти (335) | — | Прийняти |
| Decline | Відхилити (2864) | — | Відхилити |
| Continue | Продовжити (2456) | — | Продовжити |
| Complete Quest (button, COMPLETE_QUEST) | Завершити завдання (2344) | — | **Завершити завдання** |
| Complete | Завершено (2336) | Виконано (275) | Виконано (adjective, don't use for the button) |
| Goodbye | Прощавай (4423); "Goodbye." (4424) | — | Прощавай |
| Cancel (QuestFrameGoodbyeButton text, QuestFrame.xml:96) | Скасувати (1720) | — | Скасувати |
| Objectives | Цілі (6672) | — | Цілі |
| Quest Objectives | Цілі завдання (7553) | Цілі завдання (265) | Цілі завдання |
| Reward | Нагорода (8267) | — | Нагорода |
| Rewards | Нагороди (8273) | Нагороди (266) | Нагороди |
| Rewards: | Нагороди: (8274) | — | Нагороди: |
| Requirements | Вимоги (8094) | Вимоги (267) | Вимоги |
| Quest Complete | Завдання виконано (7540) | — | Завдання виконано |
| Quest Complete! | Завдання виконано! (7541) | — | Завдання виконано! |
| Description | Опис (2961) | Опис (264) | Опис |
| Progress | Поступ (7438) | — | Поступ |
| Completion | Завершення (2382) | Завершення (268) | Завершення |
| You will receive: | Ви отримаєте: (12616) | Ви отримаєте: (269) | Ви отримаєте: |
| You will also receive: | Ви також отримаєте: (12584) | same (270) | Ви також отримаєте: |
| You will be able to choose one of these rewards: | Ви зможете обрати одну з цих нагород: (12585) | same (271) | same |
| Choose your reward: | Обирай свою нагороду: (2025) | — | Обирай свою нагороду: |
| Required items: (TURN_IN_ITEMS, QuestFrame.xml:132) | Потрібні предмети: (8093) | same (273) | Потрібні предмети: |
| Required Items: | **missing** | Потрібні предмети: (272) | Потрібні предмети: |
| Required Money: | Потрібно грошей: (8091) | Потрібні гроші: (274) | **Потрібні гроші:** |
| Experience: | Досвід: (3756) | — | Досвід: |
| Current Quests | Поточні завдання (2729) | same (282) | Поточні завдання |
| Available Quests | Доступні завдання (1181) | same (283) | Доступні завдання |
| Completed Quests | Виконані завдання (2368) | Завершені завдання (284) | **Завершені завдання** |
| Quest Details | Деталі завдання (7543) | — | Деталі завдання |
| Quest Log | Журнал завдань (7551) | — | Журнал завдань |
| Abandon Quest | Відмовитися від завдання (321) | — | same |
| Learn Spell: | Вивчити закляття: (5496) | — | same |
| Ready for turn-in | Готово до здачі (7840) | — | same |
| Close / Back / Skip | Закрити (2202) / Назад (1217) / Пропустити (9120) | — | same |

**Not in UALLF** (neither table): "Quest Completed", "You will learn:", "Accept Quest", "Decline Quest", "Choose a reward:", "Reputation:", "Money:", "Bye", "Farewell", "Objective" (singular). Dialogue UI keeps its own English for these. Don't invent Ukrainian ones.

---

## 6. Recommended design: `UA(kind, english[, id])`

```lua
-- One capture helper (the bridge's Probe without Show/Hide: none of these hooks check IsShown).
local probing, probeInput, captured
local hooked = setmetatable({}, { __mode = "k" })
local function OnSetText(self, text)
    if probing ~= self or captured then return end
    if type(text) == "string" and text ~= probeInput and pcall(function() return text ~= "" end) then captured = text end
end
local function CaptureVia(obj, en)
    if not hooked[obj] then
        if not pcall(hooksecurefunc, obj, "SetText", OnSetText) then return nil end
        hooked[obj] = true
    end
    probing, probeInput, captured = obj, en, nil
    pcall(obj.SetText, obj, en)
    local r = captured
    probing, probeInput, captured = nil, nil, nil
    return r
end

local ORACLE = {
    label  = { get = function() return _G.CurrentQuestsText end, restore = function() return CURRENT_QUESTS end },
    gossip = { get = function() return _G.GreetingText end },                       -- + ChatFrameUtil fallback
    npc    = { get = function() return QuestFrame and QuestFrame:GetTitleText() end },
}
local cache = {}   -- positive results only, key = kind.."\0"..(id or "").."\0"..english

function UA(kind, english, id)
    if type(english) ~= "string" or english == "" then return nil end
    if not (C_AddOns.IsAddOnLoaded("UALLF")) or not loggedIn or UALLFShowsOriginal() then return nil end
    local key = kind .. "\0" .. tostring(id or "") .. "\0" .. english
    if cache[key] then return cache[key] end
    local ua
    if kind == "questTitle" then
        ua = id and UAQuestTitleByID(id, english)                 -- §3 A (quests.log)
          or UAQuestTitleByEnglish(english)                       -- §3 B (TaskPOI, quests.mappins) or C
    else
        local o = ORACLE[kind]; local fs = o and o.get()
        if fs then
            local before = fs:GetText()
            ua = CaptureVia(fs, english)
            pcall(fs.SetText, fs, (o.restore and o.restore()) or before or "")
        end
        if not ua and kind == "gossip" then ua = UAGossipViaChatFilter(english) end   -- §2 B
    end
    if ua and ua ~= english then cache[key] = ua; return ua end
    return nil                                                    -- caller shows English
end
```

Rules:
- **Never cache nil.** In normal mode the original key held, or a gate turned off for a moment, gives nil.
- **Clear the cache** when `UALLFSettingsDB` changes; checking it on each GOSSIP_SHOW is enough.
- Call only after PLAYER_LOGIN, never from inside a UALLF hook (`labelBusy`/`textBusy`).
- Keep the bridge's reverse-mode rule (`UALLFShowsOriginal`).
- For gossip options, pass `optionInfo.name`.
- For listed quests, pass `C_GossipInfo` questID + title.
- Results are UALLF's own lines with `$N/$C/$R/$G/$B` already localized: ChatLookup → Localize, and LogTooltipUA → Localize(title).

Priorities by risk:
- label, npc, gossip: hidden-widget probes. No visible effect, one harmless Remember entry each.
- questTitle by ID: GameTooltip-based. Accurate (the same `ns.quests[id].title` UALLF's gossip list shows), but it borrows GameTooltip, so probe only while the tooltip is hidden, or prefetch on GOSSIP_SHOW before the window shows. Otherwise fall back to C (StorageHooks, by English, precedence caveat).

Re-check after every UALLF update: these are private hooks. If a widget name or setting key changes, the oracle silently returns nil, which is safe.
