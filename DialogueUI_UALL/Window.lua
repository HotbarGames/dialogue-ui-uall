-- Dialogue UI - UALL: the rest of Dialogue UI's window in Ukrainian, with UALL Forever's own
-- texts only (no strings of ours: what UALLF can't translate stays as Dialogue UI shows it).
--
-- Where the Ukrainian comes from ("oracles"): UALLF keeps its tables private but translates any
-- English written into some hidden Blizzard font strings. We write the English there, record what
-- UALLF's SetText hook puts back, and restore the font string, all in one call (nothing is drawn
-- in between). Dialogue UI keeps QuestFrame and GossipFrame hidden, so these are never on screen,
-- and Blizzard never reads their text back.
--   label   CurrentQuestsText (QuestHooks PinLabel: UI_LABELS, then uiStrings)   setting quests.ui
--   talk    GreetingText (GossipHooks PinText: ChatLookup, $N/$C/$R filled in)   setting gossip
--   npc     QuestFrame's title (GossipHooks PinNpcTitle: npcNames)               setting gossip
--   title   a closed bag window's title (StorageHooks: uiStrings, items, NPCs,
--           then quest titles by English name)                                  setting interface.storage
--
-- Where it goes in: Dialogue UI has no public hook for these, so we wrap methods of its global
-- frame DUIQuestFrame and its global button mixins, swapping the English argument before Dialogue
-- UI measures it. Each lookup runs under pcall and falls back to the English on any error; the
-- original method is always called outside our pcall, so Dialogue UI's own errors stay its own.
-- These are private Dialogue UI method names: if an update renames one, that part stays English.

local _, ns = ...
local Text, Same = ns.Text, ns.Same

-- ── Oracles ─────────────────────────────────────────────────────────────────────

local probing, probeInput, captured
local hooked = setmetatable({}, { __mode = "k" })

-- Must never raise: it runs inside UALLF's SetText hooks while their busy flags are set.
local function OnSetText(self, text)
    if probing ~= self or captured then return end
    text = Text(text)
    if text and not Same(text, probeInput) then captured = text end
end

-- UALLF's Ukrainian for `en` written into `fs`, then `fs` gets `restore` (or its old text) back.
local function Ask(fs, en, restore)
    if probing then return nil end
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" or type(fs.GetText) ~= "function" then return nil end
    if not hooked[fs] then
        if not pcall(hooksecurefunc, fs, "SetText", OnSetText) then return nil end
        hooked[fs] = true
    end
    local before = fs:GetText()
    probing, probeInput, captured = fs, en, nil
    pcall(fs.SetText, fs, en)
    local ua = captured
    probing, probeInput, captured = nil, nil, nil
    pcall(fs.SetText, fs, restore or before)
    return ua
end

local function BagTitle()
    for i = (NUM_CONTAINER_FRAMES or 13), 1, -1 do   -- Blizzard opens the lowest free one first
        local f = _G["ContainerFrame" .. i]
        if f and f.GetTitleText and not f:IsShown() then return f:GetTitleText() end
    end
end

local ORACLE = {
    label = function(en) return Ask(_G.CurrentQuestsText, en, _G.CURRENT_QUESTS) end,
    -- "" rather than the old "Filler Text": restoring that would cost UALLF a full lookup each time
    talk  = function(en) return Ask(_G.GreetingText, en, "") end,
    npc   = function(en) local f = _G.QuestFrame return Ask(f and f.GetTitleText and f:GetTitleText(), en) end,
    title = function(en) return Ask(BagTitle(), en) end,
}

-- UALLF settings each oracle depends on: the key its hook checks, plus, for quest titles in an
-- NPC's list, "gossip" (UALLF puts those under its talk window). A switched-off setting or the
-- held original key (normal mode) means no lookup at all, not a miss.
local GATES = {
    label = { "quests.ui" },
    talk  = { "gossip" },
    npc   = { "gossip" },
    title = { "interface.storage", "gossip" },
}

local function KeyHeld(s)
    local key = s.originalKey or "SHIFT"
    return (key == "SHIFT" and IsShiftKeyDown and IsShiftKeyDown())
        or (key == "CTRL" and IsControlKeyDown and IsControlKeyDown())
        or (key == "ALT" and IsAltKeyDown and IsAltKeyDown()) or false
end

local function WillTranslate(kind)
    if ns.UALLFShowsOriginal() then return false end   -- off, or reverse mode without the key
    local s = _G.UALLFSettingsDB
    if type(s) ~= "table" then return true end
    for _, k in ipairs(GATES[kind]) do
        if s[k] == false then return false end
    end
    return s.reverseOriginal == true or not KeyHeld(s)
end

-- Answers found (never misses) for this NPC window; wiped when it closes or UALLF settings change.
local cache, cacheSig = {}, nil

local function Wipe(t)
    for k in pairs(t) do t[k] = nil end
end

local function SettingsSig()
    local s = _G.UALLFSettingsDB
    if type(s) ~= "table" then return "" end
    return tostring(s.enabled) .. tostring(s.reverseOriginal) .. tostring(s["quests.ui"])
        .. tostring(s.gossip) .. tostring(s["interface.storage"])
end

local cacheReset = CreateFrame("Frame")
cacheReset:RegisterEvent("GOSSIP_CLOSED")
cacheReset:RegisterEvent("QUEST_FINISHED")
cacheReset:SetScript("OnEvent", function() Wipe(cache) end)

-- What was looked up and missed, for /duall and bug reports (DialogueUI_UALL_DB.window).
local function Count(kind, en, ua)
    local db = ns.DB()
    local w = type(db.window) == "table" and db.window or {}
    db.window = w
    w[kind] = w[kind] or { hit = 0, miss = 0 }
    if ua then
        w[kind].hit = w[kind].hit + 1
        return
    end
    w[kind].miss = w[kind].miss + 1
    w.missed = w.missed or {}
    local line = kind .. ": " .. en:sub(1, 80)
    for _, m in ipairs(w.missed) do if m == line then return end end
    if #w.missed < 40 then table.insert(w.missed, line) end
end

-- UALLF's Ukrainian for this English text, or nil. quiet: a cross-check, not counted.
local function UA(kind, en, quiet)
    en = Text(en)
    if not en or not WillTranslate(kind) then return nil end
    local sig = SettingsSig()
    if sig ~= cacheSig then Wipe(cache); cacheSig = sig end
    local key = kind .. "\0" .. en
    if cache[key] then return cache[key] end
    local ok, ua = pcall(ORACLE[kind], en)
    ua = ok and ua and not Same(ua, en) and ua or nil
    if ua then cache[key] = ua end
    if not quiet then pcall(Count, kind, en, ua) end
    return ua
end
ns.UA = UA

-- ── Wrapping Dialogue UI ────────────────────────────────────────────────────────

local wrapped = setmetatable({}, { __mode = "k" })

-- obj[key] = make(original); once per object and key.
local function Wrap(obj, key, make)
    if type(obj) ~= "table" or type(obj[key]) ~= "function" then return end
    wrapped[obj] = wrapped[obj] or {}
    if wrapped[obj][key] then return end
    wrapped[obj][key] = true
    obj[key] = make(obj[key])
end

local function Try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
end

-- hex colours (|cffRRGGBB) and named ones (|cnWARNING_FONT_COLOR:, used in some gossip options)
local function StripColor(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", ""))
end

-- Dialogue UI's "show original" (right-click on its translator button): then its own dual
-- layout stays as it is.
local function ShowOriginal()
    local db = _G.DialogueUI_DB
    return type(db) == "table" and db.TranslatorShowOriginalText == true
end

-- A reply option's text: "<key>. " (the bound key, "1." by default) + the option, maybe coloured.
local function OptionText(name)
    local prefix, rest = name:match("^([%w%-]+%. )(.+)$")
    local ua = rest and UA("talk", StripColor(rest))
    if not ua then
        if prefix and prefix:find("^%d+%. $") then return nil end   -- a number: it was a key prefix
        prefix, rest = nil, name
        ua = UA("talk", StripColor(name))
        if not ua then return nil end
    end
    local color = rest:match("^(|c%x%x%x%x%x%x%x%x)") or rest:match("^(|cn[%w_]+:)")
    if color and rest:sub(-2) == "|r" then ua = color .. ua .. "|r" end
    return (prefix or "") .. ua
end

-- A quest in an NPC's list, by its English name. UALLF's bag lookup checks UI strings and NPC
-- names before quest titles; such a hit is not the quest's own title, so keep the English then.
local function ListTitle(name)
    local ua = UA("title", name)
    if ua and (Same(ua, UA("label", name, true)) or Same(ua, UA("npc", name, true))) then return nil end
    return ua
end

-- Buttons: reply options, quests in an NPC's list, Accept/Decline/Continue/Complete/Goodbye...
-- Every button label goes through SetButtonText, which measures it right after (Layout).
local function ButtonText(self, name)
    local t = self.type
    if t == "gossip" then
        return OptionText(name)
    elseif t == "availableQuest" or t == "activeQuest" then
        return ListTitle(name)
    elseif t == "complete" and name == (_G.COMPLETE or "Complete") then
        return UA("label", "Complete Quest")   -- UALLF's "Complete" is the adjective
    end
    return UA("label", name)
end

-- The two footer buttons are half the window wide and their height places the footer divider
-- (measured once): a label that wraps to two lines would cover the text, so keep it English then.
local function IsFooter(self)
    local o = self.owner
    return o and (self == o.AcceptButton or self == o.ExitButton)
end

local function WrapButton(obj)
    Wrap(obj, "SetButtonText", function(orig)
        return function(self, name, ...)
            local ua = Text(name) and Try(ButtonText, self, name)
            local r = orig(self, ua or name, ...)
            if ua and Try(function() return IsFooter(self) and self.Name:GetNumLines() > 1 end) then
                return orig(self, name, ...)
            end
            return r
        end
    end)
end

local function WrapTypeFrame(obj)   -- quest type tag on the right of a list entry (Daily, Weekly...)
    Wrap(obj, "SetRightText", function(orig)
        return function(self, text, ...)
            return orig(self, Try(UA, "label", text) or text, ...)
        end
    end)
end

-- Gossip text, quest greeting text and the gossip confirm text (FormatParagraph's TTS flag 0 is
-- exactly these three). The NPC's line is the end of Dialogue UI's text ("Name: " and a hint may
-- come before it), so only that tail is swapped.
local function ReplaceTail(text, en, ua)
    if #text < #en or text:sub(-#en) ~= en then return nil end
    return text:sub(1, #text - #en) .. ua
end

-- After "Show answer." Dialogue UI puts that option's text before the gossip text
-- (hint .. "\n\n" .. text) and clears the hint first, so we keep it from SetHintText.
local lastHint

local function TalkText(self, text, confirm)
    local out
    if confirm then   -- GOSSIP_CONFIRM: the whole paragraph is the line
        out = UA("talk", StripColor(text))
    else
        local en
        if self.handler == "HandleQuestGreeting" then
            en = Text(GetGreetingText and GetGreetingText())
        else
            en = Text(C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText())
        end
        local ua = en and UA("talk", en)
        out = ua and ReplaceTail(text, en, ua)
        local hint = lastHint
        lastHint = nil
        if hint then
            local base = out or text
            local s, e = base:find(hint .. "\n\n", 1, true)
            local hu = s and UA("talk", hint)
            if hu then out = base:sub(1, s - 1) .. hu .. "\n\n" .. base:sub(e + 1) end
        end
    end
    local npc = out and Text(UnitName and UnitName("npc"))
    if npc and out:find(npc .. ": ", 1, true) == 1 then
        local ua = UA("npc", npc)
        if ua then out = ua .. ": " .. out:sub(#npc + 3) end
    end
    return out
end

-- Window header: the quest title in Ukrainian instead of Dialogue UI's extra title line, while
-- its translation is on (it then calls our getter inside FormatQuestText: ns.qt.asked).
local function SetHeaderTitle(frame, text)
    local title = frame.FrontFrame.Header.Title    -- same steps as Dialogue UI's UpdateQuestTitle
    title:SetFontObject("DUIFont_Quest_Title_18")
    title:SetJustifyV("BOTTOM")
    title:SetJustifyH("LEFT")
    title:SetText(text)
    if title:GetNumLines() > 1 then
        title:SetFontObject("DUIFont_Quest_Title_16")
        if title:GetNumLines() > 1 then title:SetFontObject("DUIFont_Quest_Paragraph") end
    end
end

local function QuestTitleUA(questID)
    local data = ns.GetUALLFQuest(questID)
    local ua = data and Text(data.title)
    local en = Text(GetTitleText and GetTitleText())
    if ua and not Same(ua, en) then return ua end
end

local function Install()
    local f = _G.DUIQuestFrame
    if type(f) ~= "table" then return false end
    local qt = ns.qt

    WrapButton(_G.DUIDialogOptionButtonMixin)   -- buttons Dialogue UI creates later
    WrapButton(f.AcceptButton)                  -- if already created (Dialogue UI makes them on first use;
                                                -- then they come from the wrapped mixin above)
    WrapButton(f.ExitButton)
    if f.optionButtonPool and f.optionButtonPool.ProcessAllObjects then
        f.optionButtonPool:ProcessAllObjects(WrapButton)
    end
    WrapTypeFrame(_G.DUIDialogQuestTypeFrameMixin)
    if f.questTypeFramePool and f.questTypeFramePool.ProcessAllObjects then
        f.questTypeFramePool:ProcessAllObjects(WrapTypeFrame)
    end

    Wrap(f, "AcquireAndSetSubHeader", function(orig)   -- Objectives, Rewards, Requirements...
        return function(self, text, ...)
            return orig(self, Try(UA, "label", text) or text, ...)
        end
    end)

    Wrap(f, "SetHintText", function(orig)
        return function(self, hintText, ...)
            lastHint = Text(hintText)
            return orig(self, hintText, ...)
        end
    end)

    -- set by HandleGossipConfirm for the one paragraph it draws (its handler can be nil)
    local confirmNext = false
    Wrap(f, "HandleGossipConfirm", function(orig)
        return function(self, ...)
            confirmNext = true
            local a, b, c = orig(self, ...)
            confirmNext = false
            return a, b, c
        end
    end)

    Wrap(f, "FormatParagraph", function(orig)
        return function(self, offsetY, text, ttsFlag, ...)
            if ttsFlag == 0 and Text(text) then
                local confirm = confirmNext
                confirmNext = false
                text = Try(TalkText, self, text, confirm) or text
            end
            return orig(self, offsetY, text, ttsFlag, ...)
        end
    end)

    Wrap(f, "InsertText", function(orig)   -- "You will be able to choose one of these rewards:"
        return function(self, offsetY, text, ...)
            if Text(text) and (Same(text, _G.REWARD_CHOOSE) or Same(text, _G.REWARD_CHOICES)) then
                text = Try(UA, "label", text) or text
            end
            return orig(self, offsetY, text, ...)
        end
    end)

    Wrap(f, "FormatRewards", function(orig)   -- "You will also receive:" and similar headers
        return function(self, offsetY, rewardList, ...)
            local list = Try(function()
                local copy, changed = {}, false
                for i, d in ipairs(rewardList) do
                    if type(d) == "table" and Text(d.header) then
                        local ua = UA("label", d.header)
                        if ua then
                            local c = {}
                            for k, v in pairs(d) do c[k] = v end
                            c.header, d, changed = ua, c, true
                        end
                    end
                    copy[i] = d
                end
                return changed and copy or nil
            end)
            return orig(self, offsetY, list or rewardList, ...)
        end
    end)

    -- Drop the extra title line: once the header is Ukrainian, or when it would only repeat the
    -- English title (UALLF has the text but its title setting is off).
    Wrap(f, "InsertParagraph", function(orig)
        return function(self, offsetY, text, fontObject, ...)
            if fontObject == "DUIFont_Quest_MultiLanguage" and qt.active and not ShowOriginal()
                and (qt.title or Try(function() return Same(text, GetTitleText()) end)) then
                return offsetY
            end
            return orig(self, offsetY, text, fontObject, ...)
        end
    end)

    Wrap(f, "FormatQuestText", function(orig)
        return function(self, ...)
            qt.active, qt.asked = true, false
            qt.title = Try(QuestTitleUA, self.questID)
            local r1, r2 = orig(self, ...)
            qt.active = false
            if qt.asked and qt.title and not ShowOriginal() then Try(SetHeaderTitle, self, qt.title) end
            qt.title = nil
            return r1, r2
        end
    end)

    local portrait = f.FrontFrame and f.FrontFrame.QuestPortrait   -- quest giver's name
    Wrap(portrait, "SetName", function(orig)
        return function(self, name, ...)
            return orig(self, Try(UA, "npc", name) or name, ...)
        end
    end)
    return true
end

-- Dialogue UI (a dependency) has built its frame by the time this file runs; anything later
-- (pool buttons) goes through the wrapped mixins.
ns.windowInstalled = Try(Install) or false

-- ── Cyrillic in Dialogue UI's fonts ─────────────────────────────────────────────
-- On an English client Dialogue UI sets its own Friz Quadrata copy (frizqt__.ttf, no Cyrillic) on
-- its font objects, so Ukrainian buttons and titles came out as squares (seen in game). It ships
-- the Cyrillic copy of the same typeface next to it: use that one wherever Dialogue UI sets the
-- Latin-only file, now and on every later SetFont (font size changes). A font the player picked
-- in Dialogue UI's settings is left alone, except the game's own Friz Quadrata ("System Font"),
-- which also has no Cyrillic: that one gets the client's Cyrillic copy.
local CYRILLIC_FOR = {
    ["interface/addons/dialogueui/fonts/frizqt__.ttf"] = "Interface/AddOns/DialogueUI/Fonts/frizqt___cyr.ttf",
    ["fonts/frizqt__.ttf"] = "Fonts\\FRIZQT___CYR.TTF",
}
local fixingFont = false

local function FixFont(fontObject)
    if fixingFont then return end
    local file, size, flags = fontObject:GetFont()
    local cyr = type(file) == "string" and CYRILLIC_FOR[file:gsub("\\", "/"):lower()]
    if not cyr then return end
    fixingFont = true
    pcall(fontObject.SetFont, fontObject, cyr, size, flags or "")
    fixingFont = false
end

-- Dialogue UI's font objects are created by its Fonts.xml, before this file runs; one scan of _G.
local fontObjects = {}
for name, obj in pairs(_G) do
    if type(name) == "string" and name:find("^DUIFont_") and type(obj) == "table"
        and type(obj.GetFont) == "function" and type(obj.SetFont) == "function"
        and pcall(hooksecurefunc, obj, "SetFont", function(self) Try(FixFont, self) end) then
        table.insert(fontObjects, obj)
    end
end
for _, obj in ipairs(fontObjects) do Try(FixFont, obj) end
