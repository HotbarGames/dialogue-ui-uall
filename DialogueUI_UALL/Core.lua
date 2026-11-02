-- Dialogue UI - UALL: Ukrainian quest text from UALL Forever (UALLF) inside Dialogue UI.
--
-- Why a bridge is needed: UALLF translates by rewriting the text of Blizzard's quest window
-- (hooks on SetText of QuestInfo*/QuestProgress* font strings). Dialogue UI unregisters
-- QuestFrame's events and draws its own window from GetQuestText() & co, so those font
-- strings are never filled and the translation never reaches the screen.
--
-- How: Dialogue UI has a public translator API (DialogueUIAPI.SetTranslator, see its
-- Code/SupportedAddOns/TranslatorPublic.lua) that asks for {title, description, objective,
-- progress, completion} by questID. UALLF keeps its database private, so we read it through
-- UALLF's own hooks ("probe"): put the English text into the hidden Blizzard font string,
-- UALLF's SetText hook swaps in the Ukrainian line ($N, $C, $R, $B already substituted),
-- our own SetText hook records that line, then the font string is put back as it was.
-- If UALLF ever exposes UALLF_GetQuestTranslation(questID), that is used instead.
--
-- This file: the quest body (Detail/Progress/Complete) through that API. Only the quest the
-- NPC is showing right now (GetQuestID()) is answered: that is the only one Dialogue UI asks
-- about. The rest of the window (title, buttons, headers, NPC talk) is Window.lua.

local ADDON, ns = ...
local VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "?"
local LOG_SIZE = 30

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7DUI-UALL|r: " .. msg)
    end
end

-- A usable non-empty string, or nil. Midnight-engine clients can hand out "secret" strings
-- that throw on any comparison, so every check runs under pcall (same rule as UALLF).
local function Text(v)
    if type(v) ~= "string" then return nil end
    local ok, empty = pcall(function() return v == "" end)
    if not ok or empty then return nil end
    return v
end

local function Same(a, b)
    local ok, same = pcall(function() return a == b end)
    return not ok or same
end

local function CallGlobal(name)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn)
    return ok and Text(v) or nil
end

local function DB()
    if type(DialogueUI_UALL_DB) ~= "table" then DialogueUI_UALL_DB = {} end
    local db = DialogueUI_UALL_DB
    if type(db.log) ~= "table" then db.log = {} end
    return db
end

local function Log(entry)
    local db = DB()
    entry.at = date and date("%Y-%m-%d %H:%M:%S") or nil
    table.insert(db.log, entry)
    while #db.log > LOG_SIZE do table.remove(db.log, 1) end
end

-- Each distinct error once per session, at most 3 chat lines per session (a recurring error
-- with slightly different text must not print on every quest window); all go to the log.
local shownErrors, shownCount = {}, 0
local function ReportError(err)
    DB().lastError = err
    if shownErrors[err] or shownCount >= 3 then return end
    shownErrors[err], shownCount = true, shownCount + 1
    Print("|cffff6060не вдалося прочитати переклад|r: " .. err)
end

local function KeyHeld(s)
    local key = s.originalKey or "SHIFT"
    return (key == "SHIFT" and IsShiftKeyDown and IsShiftKeyDown())
        or (key == "CTRL" and IsControlKeyDown and IsControlKeyDown())
        or (key == "ALT" and IsAltKeyDown and IsAltKeyDown()) or false
end

-- UALLF shows the English original on its own widgets in these cases; mirror it here.
-- UALLFSettingsDB keeps only changed keys (defaults: enabled, SHIFT, normal mode). In normal
-- mode a held key needs no check here: UALLF then skips translating, so the probe gets nothing.
local function UALLFShowsOriginal()
    local s = _G.UALLFSettingsDB
    if type(s) ~= "table" then return false end
    if s.enabled == false then return true end
    if s.reverseOriginal ~= true then return false end
    return not KeyHeld(s)   -- reverse mode: English unless the key is held
end

-- Same, plus the normal mode's held key: for the quest text, so a held Shift is logged as "original",
-- not as a quest without translation.
local function QuestShowsOriginal()
    if UALLFShowsOriginal() then return true end
    local s = _G.UALLFSettingsDB
    return type(s) == "table" and s.reverseOriginal ~= true and KeyHeld(s)
        or type(s) ~= "table" and IsShiftKeyDown and IsShiftKeyDown() or false
end

ns.Text, ns.Same, ns.DB, ns.UALLFShowsOriginal = Text, Same, DB, UALLFShowsOriginal
-- Window.lua: set while Dialogue UI's FormatQuestText runs; asked = it called our getter there,
-- i.e. its translation is switched on.
ns.qt = { active = false, asked = false }

-- ── Probe through UALLF's hooks ─────────────────────────────────────────────────

-- Which Blizzard font string UALLF translates for each field, and the English source.
-- npc: UALLF reads the quest from GetQuestID(). The others read C_QuestLog's selected quest
-- whenever QuestInfoFrame.questLog is set (left over from the quest map's details view).
local TARGETS = {
    { field = "title",       widget = "QuestProgressTitleText",   english = "GetTitleText",     npc = true },
    { field = "title",       widget = "QuestInfoTitleHeader",     english = "GetTitleText" },
    { field = "description", widget = "QuestInfoDescriptionText", english = "GetQuestText" },
    { field = "objectives",  widget = "QuestInfoObjectivesText",  english = "GetObjectiveText" },
    { field = "progress",    widget = "QuestProgressText",        english = "GetProgressText",  npc = true },
    { field = "completion",  widget = "QuestInfoRewardText",      english = "GetRewardText" },
}

local probing, probeInput, captured
local captureHooked = setmetatable({}, { __mode = "k" })

local function OnSetText(self, text)
    if probing ~= self or captured then return end
    text = Text(text)
    if text and not Same(text, probeInput) then captured = text end
end

local function HookCapture(fs)
    if captureHooked[fs] then return true end
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" or type(fs.GetText) ~= "function" then
        return false
    end
    local ok = pcall(hooksecurefunc, fs, "SetText", OnSetText)
    if ok then captureHooked[fs] = true end
    return ok
end

-- Returns the Ukrainian line for this widget (or nil), a function that puts the widget
-- back, and an error text if a SetText hook failed. The restore runs after
-- QuestInfoFrame.questLog is restored.
local function Probe(fs, input)
    if not HookCapture(fs) then return nil end
    local wasShown = fs:IsShown()
    local before = fs:GetText()
    if not wasShown then fs:Show() end   -- UALLF translates only shown font strings

    probing, probeInput, captured = fs, input or "", nil
    local ok, err = pcall(fs.SetText, fs, probeInput)
    local result = captured   -- already passed Text(); keep it even if a later hook failed
    probing, probeInput, captured = nil, nil, nil

    local function restore()
        -- hidden first: UALLF leaves hidden font strings alone, so the old text comes back as is
        if not wasShown then fs:Hide() end
        pcall(fs.SetText, fs, before)
    end
    return result, restore, (not ok) and tostring(err) or nil
end

-- Blizzard views that read QuestInfoFrame.questLog without a fresh QuestInfo_Display first
-- (reward buttons' OnEnter/OnClick in QuestInfo.lua).
local function BlizzardQuestViewVisible()
    local function vis(f) return type(f) == "table" and f.IsVisible and f:IsVisible() end
    return vis(QuestInfoFrame) or vis(QuestMapFrame and QuestMapFrame.DetailsFrame)
        or vis(QuestLogPopupDetailFrame) or vis(QuestFrame)
        or vis(MapQuestInfoRewardsFrame) or vis(QuestInfoRewardsFrame)
end

local function ProbeQuest(questID)
    local data, restores, errs = {}, {}, {}
    local qi = QuestInfoFrame
    local QL = C_QuestLog
    local how, prevSelected, savedLog   -- how: nil | "select" | "write" | "npc-only"

    -- UALLF's QuestInfo* hooks read C_QuestLog's selected quest while QuestInfoFrame.questLog
    -- is set (left by the quest map). Ways to point them at our quest, best first:
    --   select:   C_QuestLog.SetSelectedQuest and back (C side, no taint; Blizzard does the
    --             same in QuestMapQuestOptions_AbandonQuest). Works for quests in the log.
    --   write:    clear the Lua field for the probe. Our write taints it until Blizzard's next
    --             QuestInfo_Display, so only while no Blizzard quest view can read it.
    --   npc-only: otherwise probe just the GetQuestID() widgets (title, progress). Also used
    --             whenever the map shows the QuestInfo widgets: their text and UALLF's Shift
    --             state belong to the quest on the map.
    if qi and qi.questLog and QL and QL.GetSelectedQuest then
        prevSelected = QL.GetSelectedQuest()
        if prevSelected ~= questID then
            if qi:IsVisible() then
                how = "npc-only"
            else
                -- only when the old selection can be put back (it may have been turned in)
                local canRestore = not prevSelected or prevSelected == 0 or not QL.GetLogIndexForQuestID
                    or QL.GetLogIndexForQuestID(prevSelected) ~= nil
                if QL.SetSelectedQuest and canRestore then
                    pcall(QL.SetSelectedQuest, questID)
                    if QL.GetSelectedQuest() == questID then
                        how = "select"
                    else
                        pcall(QL.SetSelectedQuest, prevSelected)
                    end
                end
                if not how then
                    if BlizzardQuestViewVisible() then
                        how = "npc-only"
                    else
                        savedLog, how = qi.questLog, "write"
                        qi.questLog = nil
                    end
                end
            end
        end
    end

    local ok, err = pcall(function()
        for _, t in ipairs(TARGETS) do
            if not data[t.field] and (t.npc or how ~= "npc-only") then
                local ua, restore, perr = Probe(_G[t.widget], CallGlobal(t.english))
                if restore then table.insert(restores, restore) end
                if perr then table.insert(errs, t.widget .. ": " .. perr) end
                data[t.field] = ua
            end
        end
    end)
    if not ok then table.insert(errs, tostring(err)) end

    -- selection first, then the widgets: a visible map is re-translated for its own quest
    if how == "select" then
        pcall(QL.SetSelectedQuest, prevSelected)
    elseif how == "write" then
        qi.questLog = savedLog
    end
    for i = #restores, 1, -1 do pcall(restores[i]) end
    return data, how, (#errs > 0) and table.concat(errs, " | ") or nil
end

-- ── Translator for Dialogue UI ──────────────────────────────────────────────────

local cache = { questID = nil, at = nil, data = nil }

local function Fields(data)
    local s = ""
    for _, k in ipairs({ "title", "description", "objectives", "progress", "completion" }) do
        if data and data[k] then s = s .. k:sub(1, 1) end
    end
    return s
end

-- Dialogue UI sets DUIQuestFrame.handler before it builds the window and asks us. Without
-- the text of this window, answer nil so it doesn't show a translator button that does nothing.
local NEED = { HandleQuestDetail = "description", HandleQuestProgress = "progress",
               HandleQuestComplete = "completion" }

local function ForWindow(result)
    local frame = _G.DUIQuestFrame
    local need = result and type(frame) == "table" and NEED[frame.handler]
    if need and not result[need] then return nil end
    return result
end

local function GetUALLFQuest(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return nil end

    -- Dialogue UI asks twice while it builds one window: answer from the same frame.
    local now = GetTime and GetTime()
    if now and cache.questID == questID and cache.at == now then return ForWindow(cache.data) end

    -- UALLF's own settings first, for either source
    if QuestShowsOriginal() then
        if questID == (GetQuestID and GetQuestID()) then Log({ questID = questID, src = "original", got = "" }) end
        return nil
    end

    local data, source, how, err
    local api = _G.UALLF_GetQuestTranslation
    if type(api) == "function" then
        local ok, res = pcall(api, questID)
        if ok and type(res) == "table" then
            -- a copy: never write into another addon's table. Text still holding $N/$B tokens is not
            -- localized for the player: don't show it, fall back to the probe.
            local function Clean(v)
                v = Text(v)
                local ok2, raw = pcall(function() return v and v:find("%$[NnBbCcRrGg]") end)
                return (ok2 and not raw) and v or nil
            end
            data = { title = Clean(res.title), description = Clean(res.description),
                     objectives = Clean(res.objectives or res.objective), progress = Clean(res.progress),
                     completion = Clean(res.completion) }
            if not (data.description or data.progress or data.completion) then data = nil end
            source = data and "api" or nil
        end
    end
    if not data then
        if questID ~= (GetQuestID and GetQuestID()) then return nil end
        data, how, err = ProbeQuest(questID)
        source = "probe"
    end

    -- Dialogue UI treats a quest without a title as untranslated; keep the English title
    -- when only UALLF's title setting is off.
    if not data.title and (data.description or data.progress or data.completion) then
        data.title = CallGlobal("GetTitleText")
    end

    Log({ questID = questID, src = source, got = Fields(data), questLog = how,
          window = type(DUIQuestFrame) == "table" and DUIQuestFrame.handler or nil,
          err = err, title = data.title })
    if err then ReportError(err) end

    local result
    if data.description or data.progress or data.completion then
        result = {
            title = data.title,
            description = data.description,
            objective = data.objectives,
            progress = data.progress,
            completion = data.completion,
        }
    end
    cache.questID, cache.at, cache.data = questID, now, result
    return ForWindow(result)
end
ns.GetUALLFQuest = GetUALLFQuest

-- Dialogue UI calls the getter mid-render without pcall: an error here would leave its
-- window half-built, so nothing may escape.
local function SafeGetUALLFQuest(questID)
    if ns.qt.active then ns.qt.asked = true end
    DB().asked = true   -- Dialogue UI really uses us (Window.lua's own calls don't count)
    local ok, res = pcall(GetUALLFQuest, questID)
    if ok then return res end
    ReportError(tostring(res))
    return nil
end

-- Dialogue UI's own copy has all Ukrainian letters (cmap checked: Ґґ Єє Іі Її); the client
-- font UALLF uses is the fallback.
local FONTS = {
    "Interface\\AddOns\\DialogueUI\\Fonts\\frizqt___cyr.ttf",
    "Fonts\\FRIZQT___CYR.TTF",
}

local function CyrFont()
    local fs = UIParent and UIParent:CreateFontString(nil, "BACKGROUND")
    if not fs then return FONTS[1] end
    fs:Hide()
    for _, path in ipairs(FONTS) do
        local ok, set = pcall(fs.SetFont, fs, path, 12, "")
        if ok and set then return path end
    end
    return FONTS[1]
end

local function Register()
    local db = DB()
    db.version = VERSION
    db.asked = nil
    if not (DialogueUIAPI and type(DialogueUIAPI.SetTranslator) == "function") then
        db.registered = false
        Print("|cffff6060у цій версії Dialogue UI немає API для перекладачів|r — завдання в його вікні лишаться англійською. Оновіть Dialogue UI.")
        return
    end
    -- Dialogue UI reports a refusal with a chat line, not an error; db.asked shows that the
    -- getter is really in use.
    local ok, err = pcall(DialogueUIAPI.SetTranslator, {
        name = "UALL Forever",
        font = CyrFont,
        questDataGetter = SafeGetUALLFQuest,
    })
    db.registered = ok
    if not ok then
        db.lastError = tostring(err)
        Print("|cffff6060не вдалося підключитися до Dialogue UI|r: " .. tostring(err))
    end
end

-- Ukrainian only. Dialogue UI's default for translators is English with the translation under
-- each paragraph (TranslatorShowOriginalText = true); players of UALL want just Ukrainian.
-- Set once, so a later right-click on Dialogue UI's translator button (shows English too) sticks.
-- Dialogue UI dims the translation font whenever it re-applies a theme, as if English were
-- shown (ThemeUtil:UpdateMultiLanguageFontColor() without an argument); give it the normal
-- paragraph colour back while English is hidden.
local coloring = false
local function FixTranslationColor()
    local ua, para = _G.DUIFont_Quest_MultiLanguage, _G.DUIFont_Quest_Paragraph
    local db = _G.DialogueUI_DB
    if coloring or not (ua and para and type(db) == "table") or db.TranslatorShowOriginalText ~= false then return end
    coloring = true
    pcall(function() ua:SetTextColor(para:GetTextColor()) end)
    coloring = false
end

local function UkrainianOnly()
    local db = DB()
    local dui = _G.DialogueUI_DB
    if not db.ukrainianOnlySet and type(dui) == "table" then
        dui.TranslatorShowOriginalText = false
        db.ukrainianOnlySet = true
    end
    local ua = _G.DUIFont_Quest_MultiLanguage
    if ua and type(ua.SetTextColor) == "function" then
        pcall(hooksecurefunc, ua, "SetTextColor", FixTranslationColor)
    end
    FixTranslationColor()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    for _, t in ipairs(TARGETS) do HookCapture(_G[t.widget]) end
    UkrainianOnly()
    Register()
end)

-- ── /duall: status and a live check on the open quest ─────────────────────────

local function Slash(msg)
    local db = DB()
    msg = Text(msg) and msg:lower() or ""
    if msg:find("test") then
        local questID = GetQuestID and GetQuestID() or 0
        if not questID or questID == 0 then
            Print("спершу відкрийте вікно завдання (поговоріть з NPC), тоді повторіть /duall test")
            return
        end
        cache.questID = nil
        local ok, data = pcall(GetUALLFQuest, questID)
        if not ok then
            Print("|cffff6060помилка|r: " .. tostring(data))
        elseif not data then
            local last = db.log[#db.log]
            local got = last and Text(last.got)
            Print(("завдання %d: перекладу для цього вікна немає (отримані поля: %s%s)"):format(questID,
                got and ("«" .. got .. "»") or "жодного",
                last and last.src == "original" and "; UALL Forever зараз показує оригінал (клавіша або обернений режим)" or ""))
        else
            Print(("завдання %d: назва «%s», поля: %s"):format(questID, tostring(data.title),
                Fields({ title = data.title, description = data.description, objectives = data.objective,
                         progress = data.progress, completion = data.completion })))
        end
        return
    end
    local settings = _G.UALLFSettingsDB
    Print(("версія %s · API Dialogue UI: %s · підключено: %s%s · UALLF: %s%s"):format(
        VERSION,
        (DialogueUIAPI and DialogueUIAPI.SetTranslator) and "є" or "|cffff6060немає|r",
        db.registered and "так" or "|cffff6060ні|r",
        db.registered and not db.asked and " (Dialogue UI ще не просив перекладу)" or "",
        (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("UALLF")) and "завантажено" or "|cffff6060не завантажено|r",
        (type(settings) == "table" and settings.enabled == false) and " (переклад UALLF вимкнено в налаштуваннях)" or ""))
    local last = db.log[#db.log]
    if last then
        local SOURCE = { api = "API UALL Forever", probe = "зчитано з вікна", original = "оригінал" }
        Print(("останнє: завдання %s, джерело: %s, поля «%s»%s"):format(tostring(last.questID),
            SOURCE[last.src] or tostring(last.src), tostring(last.got), last.err and (" · помилка: " .. last.err) or ""))
    end
    Print("літери полів: t — назва, d — опис, o — цілі, p — прогрес, c — завершення. /duall test — перевірити відкрите завдання.")
end

SLASH_DUALL1 = "/duall"
SlashCmdList.DUALL = function(msg)
    local ok, err = pcall(Slash, msg)   -- an old SavedVariables shape must not break the command
    if not ok then Print("|cffff6060помилка|r: " .. tostring(err)) end
end
