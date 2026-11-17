-- AKForeverFastTurnin - the clicks of a repeatable hand-in, made for you (the user, 2026-11-16: "to help
-- turnin things that you end up talking through npc dialog and clicking through stuff like waylaid
-- crates ... the dokimi npc should automatically accept the a sealed crate quest").
--
-- WHAT IT CLICKS THROUGH: a quest the game calls repeatable (the NPC's list says so, or the quest log
-- does), plus the quests of Quests.lua whatever the game calls them - the eight "A Sealed Crate" quests
-- and the Craftsman's Writs. Every other quest is the player's, every step of it.
--
-- ESCORTS (the user, 2026-11-16: "can we also include starting escort quests"): the escorts of Quests.lua
-- are STARTED for you - picked from the NPC's list and accepted - and when someone in the party starts
-- one, the game's "would you like to as well?" is answered yes (QUEST_ACCEPT_CONFIRM -> ConfirmAcceptQuest,
-- what the Yes button of Blizzard's QUEST_ACCEPT dialog calls). Handing an escort in stays yours.
-- The quests of Quests.never are never started and never joined ("make sure this does not work for the
-- escort quest inside of RFD"). '/akft escorts off' leaves all of them to you.
--
-- HOW: nothing is remembered about "where we are". Each window the game opens is looked at on its own
-- and gets the one click a person would make there:
--     the NPC's list (GOSSIP_SHOW / the older QUEST_GREETING)  -> open a quest that is ready to hand
--                                                                  in, else one to pick up
--     the quest's offer (QUEST_DETAIL)                           -> Accept
--     "do you have it?" (QUEST_PROGRESS)                         -> Continue, when everything is there
--     the reward (QUEST_COMPLETE)                                -> Complete, when there is nothing to
--                                                                  choose and nothing to pay
-- So several crates go one after another for as long as the NPC's window keeps coming back, and where
-- it does not, talking to the NPC again carries on from wherever things stand.
--
-- WHERE IT STOPS: Shift held, '/akft off', a choice of rewards, a hand-in that costs gold, things still
-- missing, a sealed crate quest whose crate is not in the bags (accepting those would fill the quest
-- log with crates you do not have), and a window that comes back without anything having happened.
--
-- None of the calls is protected (read in the Forever client's GossipInfoDocumentation.lua and
-- Mainline/QuestFrame.lua, 2026-11-16: Blizzard's own buttons call the very same functions).
local ADDON, ns = ...
ns.name = ADDON

local GOLD = "|cffffd100"
local R = "|r"
local PREFIX = GOLD .. "FastTurnin:" .. R .. " "

local LOG_MAX = 40     -- lines kept (and saved, so they can be read after the session)
local LOG_RECENT = 10  -- a line that is among the last ten is not written again
local STALL_SECONDS = 5

local issecret = type(issecretvalue) == "function" and issecretvalue or nil

local function secret(value)
    return issecret ~= nil and issecret(value) and true or false
end

-- A plain positive whole number (never a secret one), else nil.
function ns.Plain(value)
    if secret(value) then
        return nil
    end
    if type(value) == "number" and value > 0 and value == math.floor(value) then
        return value
    end
    return nil
end

-- true only for a plain true (a secret answer is "not known")
local function yes(value)
    return not secret(value) and value == true
end

-- Calls a global the client may not have; a failed or missing call answers nil.
local function ask(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then
        return a, b, c, d, e
    end
    return nil
end

------------------------------------------------------------------------
-- Settings and the log
------------------------------------------------------------------------
local fallback = { enabled = true, log = {} } -- before the saved table is there

local function db()
    return type(AKForeverFastTurninDB) == "table" and AKForeverFastTurninDB or fallback
end

function ns.Enabled()
    return db().enabled ~= false
end

-- One line about what was done or left alone, for '/akft log'. A line that is already among the last
-- few is not written again: an NPC whose window comes back says the same things every time.
function ns.Log(text)
    local log = db().log
    if type(log) ~= "table" then
        log = {}
        db().log = log
    end
    for index = math.max(1, #log - LOG_RECENT + 1), #log do
        if type(log[index]) == "table" and log[index].text == text then
            return
        end
    end
    log[#log + 1] = { at = ask(date, "%H:%M:%S") or "", text = text }
    while #log > LOG_MAX do
        table.remove(log, 1)
    end
end

local function name(title, id)
    if secret(title) or type(title) ~= "string" or title == "" then
        title = "?"
    end
    return title .. " (" .. tostring(id) .. ")"
end

------------------------------------------------------------------------
-- Which quests, and whether the crate is there
------------------------------------------------------------------------
local flagged = {} -- [quest id] = true: an NPC's list marked it as repeatable (this session)
local NEVER_TEXT = ": left alone - this one is never started for you"

-- Is this a quest that is never started and never joined for you? By its number; by its name where
-- the game gives no number.
function ns.Never(id, title)
    if id then
        return ns.Quests.never[id] ~= nil
    end
    if secret(title) or type(title) ~= "string" then
        return false
    end
    for _, known in pairs(ns.Quests.never) do
        if known == title then
            return true
        end
    end
    return false
end

function ns.EscortsOn()
    return db().escorts ~= false
end

-- Is this an escort to start for you? (Started only: its hand-in is not ns.Wanted.)
function ns.Starts(id)
    return ns.EscortsOn() and ns.Quests.escorts[id] == true and not ns.Never(id)
end

-- true + why, or false: is this a quest to click through?
function ns.Wanted(id)
    if ns.Never(id) then
        return false
    end
    if ns.Quests.sealed[id] then
        return true, "a sealed crate"
    end
    if ns.Quests.writs[id] then
        return true, "a writ"
    end
    if flagged[id] then
        return true, "repeatable"
    end
    local log = type(C_QuestLog) == "table" and C_QuestLog or nil
    if log and yes(ask(log.IsRepeatableQuest, id)) then
        return true, "repeatable"
    end
    return false
end

local function itemCount(what)
    local get = (type(C_Item) == "table" and C_Item.GetItemCount) or GetItemCount
    local count = ask(get, what)
    if secret(count) or type(count) ~= "number" then
        return 0
    end
    return count
end

-- Is the crate this "A Sealed Crate" quest wants in the bags? nil for any other quest (not known, and
-- not in the way). Four of the eight crates have an item number that is not confirmed (see
-- tools/gen_quests.py): those are looked for by their name too.
function ns.Holding(id)
    local crate = ns.Quests.sealed[id]
    if not crate then
        return nil
    end
    if itemCount(crate.item) > 0 then
        return true
    end
    return not crate.confirmed and itemCount(crate.name) > 0
end

------------------------------------------------------------------------
-- One click, never the same one twice running
------------------------------------------------------------------------
local last -- { key, at }: the click made last

-- Makes the call unless it is the very click that was made last, a moment ago: then the game did not
-- move on (a full quest log, a refusal, the same event sent twice), and asking again would only spin.
local function click(key, fn, ...)
    local now = ask(GetTime) or 0
    if last and last.key == key and now - last.at < STALL_SECONDS then
        return false
    end
    last = { key = key, at = now } -- (before the call: its answer may arrive before it returns)
    if type(fn) == "function" then
        fn(...)
    end
    return true
end

local function handsOff()
    return not ns.Enabled() or yes(ask(IsShiftKeyDown))
end

------------------------------------------------------------------------
-- The NPC's list
------------------------------------------------------------------------
-- rows: { { id, title, complete (active rows), repeatable, pick = the argument its Select call takes } }
local function fromList(active, available, selectActive, selectAvailable)
    for _, row in ipairs(active) do
        if row.repeatable then
            flagged[row.id] = true
        end
        if row.complete and ns.Wanted(row.id) then
            return click("active:" .. row.id, selectActive, row.pick)
        end
    end
    for _, row in ipairs(available) do
        if row.repeatable then
            flagged[row.id] = true
        end
        if ns.Never(row.id) then
            ns.Log(name(row.title, row.id) .. NEVER_TEXT)
        elseif ns.Starts(row.id) then
            return click("available:" .. row.id, selectAvailable, row.pick)
        elseif not ns.Wanted(row.id) then
            ns.Log(name(row.title, row.id) .. ": left alone - not repeatable")
        elseif ns.Holding(row.id) ~= false then
            return click("available:" .. row.id, selectAvailable, row.pick)
        end
    end
    return false
end

local function gossipRows(list)
    local rows = {}
    if type(list) ~= "table" then
        return rows
    end
    for _, info in ipairs(list) do
        local id = type(info) == "table" and ns.Plain(info.questID)
        if id then
            rows[#rows + 1] = { id = id, title = info.title, complete = yes(info.isComplete),
                repeatable = yes(info.repeatable), pick = id }
        end
    end
    return rows
end

function ns.OnGossip()
    local gossip = type(C_GossipInfo) == "table" and C_GossipInfo or nil
    if handsOff() or not gossip then
        return
    end
    fromList(gossipRows(ask(gossip.GetActiveQuests)), gossipRows(ask(gossip.GetAvailableQuests)),
        gossip.SelectActiveQuest, gossip.SelectAvailableQuest)
end

-- The older window of an NPC that has quests and nothing else to say: the same list, asked for row by row.
function ns.OnGreeting()
    if handsOff() then
        return
    end
    local active, available = {}, {}
    for index = 1, ns.Plain(ask(GetNumActiveQuests)) or 0 do
        local title, complete = ask(GetActiveTitle, index)
        local id = ns.Plain(ask(GetActiveQuestID, index))
        if id then
            active[#active + 1] = { id = id, title = title, complete = yes(complete), pick = index }
        end
    end
    for index = 1, ns.Plain(ask(GetNumAvailableQuests)) or 0 do
        local _, _, repeatable, _, questID = ask(GetAvailableQuestInfo, index)
        local id = ns.Plain(questID)
        if id then
            available[#available + 1] = { id = id, title = ask(GetAvailableTitle, index),
                repeatable = yes(repeatable), pick = index }
        end
    end
    fromList(active, available, SelectActiveQuest, SelectAvailableQuest)
end

------------------------------------------------------------------------
-- The quest's own windows
------------------------------------------------------------------------
-- id and name of the quest whose window is open, when it is one of ours and nothing says hands off
local function openQuest()
    if handsOff() then
        return nil
    end
    local id = ns.Plain(ask(GetQuestID))
    if not id or not ns.Wanted(id) then
        return nil
    end
    return id, name(ask(GetTitleText), id)
end

function ns.OnDetail()
    if handsOff() then
        return
    end
    local id = ns.Plain(ask(GetQuestID))
    if not id then
        return
    end
    local title = name(ask(GetTitleText), id)
    if ns.Never(id) then
        ns.Log(title .. NEVER_TEXT)
        return
    end
    local escort = ns.Starts(id)
    if not escort and not ns.Wanted(id) then
        return
    end
    if ns.Holding(id) == false then
        ns.Log(title .. ": left alone - its crate is not in your bags")
        return
    end
    ns.Log(title .. (escort and ": started - an escort" or ": picked up"))
    if yes(ask(QuestGetAutoAccept)) then
        click("accept:" .. id, AcknowledgeAutoAcceptQuest) -- the game took it already: only the window is left
    else
        click("accept:" .. id, AcceptQuest)
    end
end

function ns.OnProgress()
    local id, title = openQuest()
    if not id then
        return
    end
    if not yes(ask(IsQuestCompletable)) then
        ns.Log(title .. ": left alone - not everything it asks for is there")
        return
    end
    click("complete:" .. id, CompleteQuest)
end

function ns.OnComplete()
    local id, title = openQuest()
    if not id then
        return
    end
    local choices = ask(GetNumQuestChoices)
    local money = ask(GetQuestMoneyToGet)
    if secret(choices) or secret(money) then
        return
    end
    choices, money = tonumber(choices) or 0, tonumber(money) or 0
    if choices > 1 then
        ns.Log(title .. ": left alone - a choice of rewards is yours to make")
        return
    end
    if money > 0 then
        ns.Log(title .. ": left alone - handing it in costs gold")
        return
    end
    ns.Log(title .. ": handed in")
    click("reward:" .. id, GetQuestReward, choices == 1 and 1 or 0) -- (what Blizzard's own button passes)
end

------------------------------------------------------------------------
-- Someone in the party starts an escort: "would you like to as well?"
------------------------------------------------------------------------
function ns.OnConfirm(starter, title, questID)
    if handsOff() or not ns.EscortsOn() then
        return
    end
    local id = ns.Plain(questID)
    local known = id
    if not known and not secret(title) and type(title) == "string" and title ~= "" then
        known = title
    end
    if not known then
        return -- which quest is not told: it could be the one that is never joined
    end
    local label = name(title, id or "?")
    if ns.Never(id, title) then
        ns.Log(label .. NEVER_TEXT)
        return
    end
    if type(ConfirmAcceptQuest) ~= "function" then
        return
    end
    if click("confirm:" .. tostring(known), ConfirmAcceptQuest) then
        local who = (not secret(starter) and type(starter) == "string" and starter ~= "") and starter or "someone"
        ns.Log(label .. ": joined - " .. who .. " started it")
        ask(StaticPopup_Hide, "QUEST_ACCEPT") -- the question is answered: Blizzard's dialog can go
    end
end

------------------------------------------------------------------------
-- Events and the slash command
------------------------------------------------------------------------
local HANDLERS = {
    GOSSIP_SHOW = ns.OnGossip,
    QUEST_GREETING = ns.OnGreeting,
    QUEST_DETAIL = ns.OnDetail,
    QUEST_PROGRESS = ns.OnProgress,
    QUEST_COMPLETE = ns.OnComplete,
    QUEST_ACCEPT_CONFIRM = ns.OnConfirm, -- (name, quest title, quest id)
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
for event in pairs(HANDLERS) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, arg, ...)
    if event == "ADDON_LOADED" then
        if arg == ADDON then
            if type(AKForeverFastTurninDB) ~= "table" then
                AKForeverFastTurninDB = {}
            end
            if type(AKForeverFastTurninDB.log) ~= "table" then
                AKForeverFastTurninDB.log = {}
            end
        end
        return
    end
    HANDLERS[event](arg, ...)
end)

local function status()
    if ns.Enabled() then
        print(PREFIX .. "on - repeatable quests, sealed crates and Craftsman's Writs are accepted and handed in for you. "
            .. "Hold Shift while you talk to an NPC to do it yourself.")
        print(PREFIX .. "escorts: " .. (ns.EscortsOn() and "on - an escort is started when you talk to its NPC, and joined when "
            .. "someone in your party starts one" or "off - starting and joining an escort is yours") .. ".")
    else
        print(PREFIX .. "off - every quest window is yours.")
    end
    print(PREFIX .. GOLD .. "/akft on" .. R .. ", " .. GOLD .. "/akft off" .. R .. ", " .. GOLD .. "/akft escorts on" .. R
        .. ", " .. GOLD .. "/akft escorts off" .. R .. ", " .. GOLD .. "/akft log" .. R
        .. " (what it did, what it left alone and why).")
end

local function showLog()
    local log = db().log
    if type(log) ~= "table" or #log == 0 then
        print(PREFIX .. "nothing yet.")
        return
    end
    for index = math.max(1, #log - 14), #log do
        local line = log[index]
        if type(line) == "table" then
            print(PREFIX .. tostring(line.at) .. " " .. tostring(line.text))
        end
    end
end

local function slash(text)
    local word, value = string.match(string.lower(text or ""), "^%s*(%S*)%s*(%S*)")
    if word == "on" or word == "off" then
        db().enabled = word == "on"
        status()
    elseif word == "escorts" or word == "escort" then
        if value == "on" or value == "off" then
            db().escorts = value == "on"
        end
        print(PREFIX .. "escorts: " .. (ns.EscortsOn() and "on" or "off") .. ". " .. GOLD .. "/akft escorts on" .. R .. " or "
            .. GOLD .. "off" .. R .. ".")
    elseif word == "log" then
        showLog()
    else
        status()
    end
end

SLASH_AKFOREVERFASTTURNIN1 = "/akft"
SLASH_AKFOREVERFASTTURNIN2 = "/fastturnin"
SlashCmdList["AKFOREVERFASTTURNIN"] = slash
