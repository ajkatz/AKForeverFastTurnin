-- AKForeverFastTurnin scenario tests. Run from the repo root:  lua tests/run.lua
-- Every scenario loads a fresh copy of the addon (the real Quests.lua and Core.lua) into a small
-- stand-in for the client and fails if the addon raised any Lua error.

local failures, passed = {}, 0

local function check(condition, message)
    if not condition then
        error(message or "check failed", 2)
    end
end

local function equal(actual, expected, what)
    if actual ~= expected then
        error((what or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function plain(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- A fresh client. opts:
--   items = { [item id or name] = how many are in the bags }
--   repeatable = { [quest id] = true }      what C_QuestLog.IsRepeatableQuest answers
--   db = the saved table from last session
--   secret = a value issecretvalue() says yes to
--   without = { "C_GossipInfo", ... }       calls this client does not have
local function client(opts)
    opts = opts or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.printed, env.calls, env.errors = {}, {}, {}
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring((select(i, ...)))
        end
        env.printed[#env.printed + 1] = plain(table.concat(parts, " "))
    end
    local function call(name, ...)
        local parts = { name }
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring((select(i, ...)))
        end
        env.calls[#env.calls + 1] = table.concat(parts, " ")
    end
    env.now = 100
    env.GetTime = function() return env.now end
    env.date = function() return "12:00:00" end
    env.issecretvalue = function(value) return opts.secret ~= nil and value == opts.secret end
    env.SlashCmdList = {}
    env.AKForeverFastTurninDB = opts.db
    env.items = opts.items or {}
    env.repeatable = opts.repeatable or {}
    env.shift = false
    env.IsShiftKeyDown = function() return env.shift end
    env.C_Item = { GetItemCount = function(what) return env.items[what] or 0 end }
    env.C_QuestLog = { IsRepeatableQuest = function(id) return env.repeatable[id] == true end }

    -- the NPC's list (the gossip window), the older greeting window, and the open quest window
    env.gossip = { active = {}, available = {} }
    env.greeting = { active = {}, available = {} }
    env.quest = nil -- { id, title, completable, choices, money, autoAccept }
    env.npc = {}    -- what the "server" does when a call is made (see dokimi below)
    local function react(name, ...)
        if env.npc[name] then
            env.npc[name](...)
        end
    end
    env.C_GossipInfo = {
        GetActiveQuests = function() return env.gossip.active end,
        GetAvailableQuests = function() return env.gossip.available end,
        SelectActiveQuest = function(id) call("gossip.SelectActiveQuest", id); react("selectActive", id) end,
        SelectAvailableQuest = function(id) call("gossip.SelectAvailableQuest", id); react("selectAvailable", id) end,
    }
    env.GetNumActiveQuests = function() return #env.greeting.active end
    env.GetNumAvailableQuests = function() return #env.greeting.available end
    env.GetActiveTitle = function(i) return env.greeting.active[i].title, env.greeting.active[i].isComplete end
    env.GetActiveQuestID = function(i) return env.greeting.active[i].questID end
    env.GetAvailableTitle = function(i) return env.greeting.available[i].title end
    env.GetAvailableQuestInfo = function(i)
        local quest = env.greeting.available[i]
        return false, 0, quest.repeatable, false, quest.questID
    end
    env.SelectActiveQuest = function(i) call("greeting.SelectActiveQuest", i) end
    env.SelectAvailableQuest = function(i) call("greeting.SelectAvailableQuest", i) end

    env.GetQuestID = function() return env.quest and env.quest.id or 0 end
    env.GetTitleText = function() return env.quest and env.quest.title or "" end
    env.IsQuestCompletable = function() return env.quest and env.quest.completable or false end
    env.GetNumQuestChoices = function() return env.quest and env.quest.choices or 0 end
    env.GetQuestMoneyToGet = function() return env.quest and env.quest.money or 0 end
    env.QuestGetAutoAccept = function() return env.quest and env.quest.autoAccept or false end
    env.AcceptQuest = function() call("AcceptQuest"); react("accept") end
    env.AcknowledgeAutoAcceptQuest = function() call("AcknowledgeAutoAcceptQuest") end
    env.CompleteQuest = function() call("CompleteQuest"); react("complete") end
    env.GetQuestReward = function(choice) call("GetQuestReward", choice); react("reward") end
    -- "<name> is starting <quest>. Would you like to as well?" - the game's question when someone in the
    -- party starts an escort, and Blizzard's dialog for it
    env.ConfirmAcceptQuest = function() call("ConfirmAcceptQuest") end
    env.StaticPopup_Hide = function(which) call("StaticPopup_Hide", which) end

    env.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(_, fn) self.script = fn end
        env.frame = frame
        return frame
    end
    env.fire = function(event, ...)
        if env.frame and env.frame.events[event] and env.frame.script then
            local ok, err = pcall(env.frame.script, env.frame, event, ...)
            if not ok then
                env.errors[#env.errors + 1] = tostring(err)
            end
        end
    end
    for _, name in ipairs(opts.without or {}) do
        env[name] = false -- (a plain false: the lookup must not fall through to anything)
    end

    local ns = {}
    for _, file in ipairs({ "Quests.lua", "Core.lua" }) do
        local chunk = assert(loadfile(file, "t", env))
        chunk("AKForeverFastTurnin", ns)
    end
    env.ns = ns
    env.fire("ADDON_LOADED", "AKForeverFastTurnin")
    env.slash = function(text)
        env.SlashCmdList["AKFOREVERFASTTURNIN"](text or "")
    end
    return env, ns
end

local current -- the client of the running scenario, for the error check

local function scenario(name, fn)
    current = nil
    local ok, err = xpcall(fn, debug.traceback)
    if ok and current and #current.errors > 0 then
        ok, err = false, "addon raised errors:\n      " .. table.concat(current.errors, "\n      ")
    end
    if ok then
        passed = passed + 1
        print("  ok    " .. name)
    else
        failures[#failures + 1] = name
        print("  FAIL  " .. name .. "\n      " .. tostring(err):gsub("\n", "\n      "))
    end
end

local function start(opts)
    local env, ns = client(opts)
    current = env
    return env, ns
end

local function count(env, text)
    local n = 0
    for _, line in ipairs(env.calls) do
        if line == text or line:sub(1, #text + 1) == text .. " " then
            n = n + 1
        end
    end
    return n
end

local function printed(env, text)
    for _, line in ipairs(env.printed) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

-- Dokimi, as far as this addon can tell: an NPC window that lists the "A Sealed Crate" quests, takes a
-- crate for each one handed in, and offers the quest again afterwards. opts.offers = the quests on offer
-- (default: all eight), opts.closes = the window does not come back after Accept or after the reward
-- (you have to talk to the NPC again: env.talk()).
local SEALED_ORDER = { 91899, 91900, 91901, 91902, 91904, 91905, 91906, 91907 }

local function dokimi(env, opts)
    opts = opts or {}
    local sealed = env.ns.Quests.sealed
    local log, offers = {}, {}
    for _, id in ipairs(opts.offers or SEALED_ORDER) do
        offers[id] = true
    end
    env.handed, env.questLog = 0, log
    local function show()
        env.quest = nil
        env.gossip.active, env.gossip.available = {}, {}
        for _, id in ipairs(SEALED_ORDER) do
            if log[id] then
                table.insert(env.gossip.active, { questID = id, title = "A Sealed Crate",
                    isComplete = (env.items[sealed[id].item] or 0) > 0, repeatable = false })
            elseif offers[id] then
                table.insert(env.gossip.available, { questID = id, title = "A Sealed Crate", repeatable = false })
            end
        end
        env.fire("GOSSIP_SHOW")
    end
    local function back()
        if opts.closes then
            env.quest = nil
            env.fire("QUEST_FINISHED")
        else
            show()
        end
    end
    env.npc.selectAvailable = function(id)
        env.quest = { id = id, title = "A Sealed Crate" }
        env.fire("QUEST_DETAIL")
    end
    env.npc.accept = function()
        log[env.quest.id] = true
        back()
    end
    env.npc.selectActive = function(id)
        env.quest = { id = id, title = "A Sealed Crate", completable = (env.items[sealed[id].item] or 0) > 0 }
        env.fire("QUEST_PROGRESS")
    end
    env.npc.complete = function()
        env.quest.choices = 0
        env.fire("QUEST_COMPLETE")
    end
    env.npc.reward = function()
        local id = env.quest.id
        env.items[sealed[id].item] = env.items[sealed[id].item] - 1
        log[id], env.handed = nil, env.handed + 1
        back()
    end
    env.talk = show
end

print("AKForeverFastTurnin tests")

scenario("Dokimi with a sealed crate in the bags: the quest is picked, accepted and handed in without a click", function()
    local env = start({ items = { [248765] = 1 } })
    dokimi(env)
    env.talk()
    equal(env.handed, 1, "crates handed in")
    equal(env.items[248765], 0, "the crate is gone")
    equal(next(env.questLog), nil, "nothing left in the quest log")
    equal(table.concat(env.calls, ", "),
        "gossip.SelectAvailableQuest 91899, AcceptQuest, gossip.SelectActiveQuest 91899, CompleteQuest, GetQuestReward 0",
        "exactly the clicks a person makes, in their order")
end)

scenario("several sealed crates go one after another while the window keeps coming back, and it stops when they run out", function()
    local env = start({ items = { [248765] = 3, [248771] = 2 } })
    dokimi(env)
    env.talk()
    equal(env.handed, 5, "all five")
    equal(env.items[248765], 0); equal(env.items[248771], 0)
    equal(count(env, "AcceptQuest"), 5); equal(count(env, "GetQuestReward"), 5)
    equal(next(env.questLog), nil, "and no quest picked up that cannot be handed in")
    local calls = #env.calls
    env.talk()
    equal(#env.calls, calls, "talking to Dokimi with no crate left does nothing")
end)

scenario("a window that closes after every step: talking to the NPC again carries on where it stopped", function()
    local env = start({ items = { [248766] = 2 } })
    dokimi(env, { closes = true })
    env.talk()
    equal(count(env, "AcceptQuest"), 1, "first talk: accepted"); equal(env.handed, 0)
    env.talk()
    equal(env.handed, 1, "second talk: handed in")
    env.talk(); env.talk()
    equal(env.handed, 2, "and the second crate the same way")
end)

scenario("a sealed crate quest for a crate you do not hold is not accepted: the quest log is not filled with them", function()
    local env = start({ items = { [248766] = 1 } }) -- a Journeyman crate, and all eight on offer
    dokimi(env)
    env.talk()
    equal(env.handed, 1)
    equal(count(env, "gossip.SelectAvailableQuest"), 1, "only one quest was opened")
    equal(count(env, "gossip.SelectAvailableQuest 91900"), 1, "the Journeyman one")

    env = start()
    dokimi(env)
    env.talk()
    equal(#env.calls, 0, "no crate at all: nothing is touched")

    -- opened by hand without the crate: the Accept button is the player's
    env.quest = { id = 91899, title = "A Sealed Crate" }
    env.fire("QUEST_DETAIL")
    equal(count(env, "AcceptQuest"), 0)
end)

scenario("the four crates whose item number is not confirmed are found by their name as well", function()
    local env = start({ items = { ["Sealed Expert Crate"] = 1 } })
    equal(env.ns.Holding(91901), true, "by name"); equal(env.ns.Holding(91906), true, "(white and green share the name)")
    equal(env.ns.Holding(91902), false, "an Artisan crate is another thing")
    env = start({ items = { [248768] = 1 } })
    equal(env.ns.Holding(91902), true, "by the number it should have")
    -- the confirmed ones go by number only: the name is shared by the white and the green crate
    env = start({ items = { ["Sealed Apprentice Crate"] = 1 } })
    equal(env.ns.Holding(91899), false, "a confirmed crate is not guessed from a name")
    equal(env.ns.Holding(12345), nil, "any other quest: not known, and not in the way")
end)

scenario("any repeatable quest at any NPC: the list's own flag or the quest log's word counts, and a quest that is neither is left alone", function()
    local env = start({ repeatable = { [7002] = true } })
    env.gossip.available = {
        { questID = 7000, title = "A proper quest", repeatable = false },
        { questID = 7001, title = "Cloth for the cause", repeatable = true },
    }
    env.fire("GOSSIP_SHOW")
    equal(table.concat(env.calls, ", "), "gossip.SelectAvailableQuest 7001", "the one the list marks as repeatable")

    env = start({ repeatable = { [7002] = true } })
    env.gossip.available = { { questID = 7000, title = "A proper quest" }, { questID = 7002, title = "More cloth" } }
    env.fire("GOSSIP_SHOW")
    equal(table.concat(env.calls, ", "), "gossip.SelectAvailableQuest 7002", "the one the quest log calls repeatable")

    -- the quest windows themselves
    env = start({ repeatable = { [7002] = true } })
    env.quest = { id = 7000, title = "A proper quest", completable = true, choices = 0 }
    env.fire("QUEST_DETAIL"); env.fire("QUEST_PROGRESS"); env.fire("QUEST_COMPLETE")
    equal(#env.calls, 0, "an ordinary quest is the player's, every step of it")
    env.quest = { id = 7002, title = "More cloth", completable = true, choices = 0 }
    env.fire("QUEST_DETAIL"); env.fire("QUEST_PROGRESS"); env.fire("QUEST_COMPLETE")
    equal(table.concat(env.calls, ", "), "AcceptQuest, CompleteQuest, GetQuestReward 0")
end)

scenario("a quest ready to hand in goes before one to pick up, and one that is not finished is not opened", function()
    local env = start()
    env.gossip.active = {
        { questID = 7001, title = "Cloth for the cause", repeatable = true, isComplete = false },
        { questID = 7003, title = "Ore for the cause", repeatable = true, isComplete = true },
    }
    env.gossip.available = { { questID = 7004, title = "Herbs for the cause", repeatable = true } }
    env.fire("GOSSIP_SHOW")
    equal(table.concat(env.calls, ", "), "gossip.SelectActiveQuest 7003")
end)

scenario("a Craftsman's Writ: accepted when the writ is opened, handed in at the customer", function()
    local env = start()
    env.quest = { id = 94213, title = "Craftsman's Writ: Lesser Mana Potion" }
    env.fire("QUEST_DETAIL")
    equal(table.concat(env.calls, ", "), "AcceptQuest")
    env.quest = { id = 94213, title = "Craftsman's Writ: Lesser Mana Potion", completable = true, choices = 1 }
    env.fire("QUEST_PROGRESS"); env.fire("QUEST_COMPLETE")
    equal(table.concat(env.calls, ", "), "AcceptQuest, CompleteQuest, GetQuestReward 1", "one reward on offer is no choice")
    -- at the customer through his list
    env = start()
    env.gossip.active = { { questID = 94213, title = "Craftsman's Writ: Lesser Mana Potion", isComplete = true } }
    env.fire("GOSSIP_SHOW")
    equal(table.concat(env.calls, ", "), "gossip.SelectActiveQuest 94213")
end)

scenario("it stops where a person has to decide: a choice of rewards, gold to pay, things still missing", function()
    local env = start()
    env.quest = { id = 94213, title = "A writ", completable = true, choices = 2 }
    env.fire("QUEST_COMPLETE")
    equal(#env.calls, 0, "two rewards to choose from: yours to pick")
    env.quest = { id = 94213, title = "A writ", completable = true, choices = 0, money = 5000 }
    env.fire("QUEST_COMPLETE")
    equal(#env.calls, 0, "a hand-in that costs gold is never paid for you")
    env.quest = { id = 94213, title = "A writ", completable = false }
    env.fire("QUEST_PROGRESS")
    equal(#env.calls, 0, "not everything is there yet: the window stays as it is")
end)

scenario("a quest the game accepts by itself is acknowledged, not accepted twice", function()
    local env = start({ repeatable = { [7002] = true } })
    env.quest = { id = 7002, title = "More cloth", autoAccept = true }
    env.fire("QUEST_DETAIL")
    equal(table.concat(env.calls, ", "), "AcknowledgeAutoAcceptQuest")
end)

scenario("Shift held means hands off; '/akft off' the same until '/akft on' - and the switch is kept for next time", function()
    local env = start({ items = { [248765] = 1 } })
    dokimi(env)
    env.shift = true
    env.talk()
    equal(#env.calls, 0, "Shift held: nothing")
    env.shift = false
    env.slash("off")
    check(printed(env, "off"), "says so")
    env.talk()
    equal(#env.calls, 0, "switched off: nothing")
    equal(env.AKForeverFastTurninDB.enabled, false, "saved")

    local again = start({ items = { [248765] = 1 }, db = env.AKForeverFastTurninDB })
    dokimi(again)
    again.talk()
    equal(#again.calls, 0, "still off next session")
    again.slash("on")
    again.talk()
    equal(again.handed, 1, "and back on")
end)

scenario("the older greeting window is read the same way, by its row numbers", function()
    local env = start({ repeatable = { [7002] = true } })
    env.greeting.active = {
        { questID = 7000, title = "A proper quest", isComplete = true },
        { questID = 7002, title = "More cloth", isComplete = true },
    }
    env.greeting.available = { { questID = 7005, title = "Even more cloth", repeatable = true } }
    env.fire("QUEST_GREETING")
    equal(table.concat(env.calls, ", "), "greeting.SelectActiveQuest 2", "the repeatable one that is ready, by its row")

    env = start()
    env.greeting.available = {
        { questID = 7000, title = "A proper quest", repeatable = false },
        { questID = 91899, title = "A Sealed Crate", repeatable = false },
        { questID = 7005, title = "Even more cloth", repeatable = true },
    }
    env.fire("QUEST_GREETING")
    equal(table.concat(env.calls, ", "), "greeting.SelectAvailableQuest 3", "the row's own repeatable flag; a crate quest without its crate is skipped")
end)

scenario("a window that comes back without anything having happened is tried once, not again and again", function()
    local env = start()
    env.gossip.available = { { questID = 7001, title = "Cloth for the cause", repeatable = true } }
    env.fire("GOSSIP_SHOW")
    env.fire("GOSSIP_SHOW"); env.fire("GOSSIP_SHOW") -- the game did not move on
    equal(count(env, "gossip.SelectAvailableQuest"), 1, "one try")
    env.now = env.now + 10
    env.fire("GOSSIP_SHOW")
    equal(count(env, "gossip.SelectAvailableQuest"), 2, "a while later (you talked to the NPC again) it is tried afresh")
end)

scenario("a client without these calls, or one that answers in secrets: quietly nothing", function()
    local secret = 94213 -- (a writ's quest number: used unguarded, it WOULD be clicked through)
    local env = start({ secret = secret, without = { "C_QuestLog", "C_Item" } })
    env.gossip.available = { { questID = secret, title = "?", repeatable = true }, { questID = 7000, title = "A proper quest" } }
    env.gossip.active = { { questID = 91899, title = "A Sealed Crate", isComplete = secret } }
    env.fire("GOSSIP_SHOW")
    env.quest = { id = secret, title = "?", completable = true }
    env.fire("QUEST_DETAIL"); env.fire("QUEST_PROGRESS"); env.fire("QUEST_COMPLETE")
    equal(#env.calls, 0)
    equal(env.ns.Holding(91899), false, "no item call on this client: a crate cannot be seen, so its quest is not picked up")

    env = start({ without = { "C_GossipInfo", "GetQuestID", "GetNumActiveQuests", "IsShiftKeyDown" } })
    env.fire("GOSSIP_SHOW"); env.fire("QUEST_GREETING"); env.fire("QUEST_DETAIL"); env.fire("QUEST_PROGRESS"); env.fire("QUEST_COMPLETE")
    equal(#env.calls, 0)
end)

scenario("'/akft' says what it is doing; '/akft log' lists what it did and what it left alone, and why", function()
    local env = start({ items = { [248765] = 1 } })
    env.slash("")
    check(printed(env, "on"), "its state")
    check(printed(env, "Shift"), "and how to hold it off")
    dokimi(env)
    env.gossip.available = { { questID = 7000, title = "A proper quest" } }
    env.fire("GOSSIP_SHOW")
    env.talk()
    env.slash("log")
    check(printed(env, "A proper quest (7000): left alone - not repeatable"), table.concat(env.printed, " | "))
    check(printed(env, "A Sealed Crate (91899): picked up"), "what it did")
    check(printed(env, "A Sealed Crate (91899): handed in"), "to the end")
    check(#env.AKForeverFastTurninDB.log <= 40, "the saved log is short")

    -- the log is saved, so it can be read after the session
    local again = start({ db = env.AKForeverFastTurninDB })
    again.slash("log")
    check(printed(again, "A Sealed Crate (91899): handed in"), "there next session")
    for n = 1, 100 do
        again.ns.Log("line " .. n)
    end
    again.ns.Log("line 100"); again.ns.Log("line 95")
    equal(#again.AKForeverFastTurninDB.log, 40, "and never grows past forty lines - nor repeats what it has just said")
    equal(again.AKForeverFastTurninDB.log[40].text, "line 100")
end)

-- An escort NPC, as far as this addon can tell: a list with the quest on offer, and its offer window.
local function escortNPC(env, id, title, extra)
    local row = { questID = id, title = title, repeatable = false }
    for key, value in pairs(extra or {}) do
        row[key] = value
    end
    env.quest = nil
    env.gossip.active, env.gossip.available = {}, { row }
    env.npc.selectAvailable = function(picked)
        env.quest = { id = picked, title = title }
        env.fire("QUEST_DETAIL")
    end
    env.now = env.now + 10
    env.fire("GOSSIP_SHOW")
end

scenario("an escort is started for you: picked from the NPC's list and accepted - and handed in by you, not by the addon", function()
    local env = start()
    escortNPC(env, 219, "Missing In Action")
    equal(count(env, "gossip.SelectAvailableQuest 219"), 1)
    equal(count(env, "AcceptQuest"), 1)
    check(env.AKForeverFastTurninDB.log[1].text:find("Missing In Action (219): started - an escort", 1, true), env.AKForeverFastTurninDB.log[1].text)

    -- an NPC whose first window is the offer itself
    env.now = env.now + 10
    env.quest = { id = 435, title = "Escorting Erland" }
    env.fire("QUEST_DETAIL")
    equal(count(env, "AcceptQuest"), 2)

    -- the older greeting window
    env.now = env.now + 10
    env.greeting.available = { { questID = 863, title = "The Escape", repeatable = false } }
    env.fire("QUEST_GREETING")
    equal(count(env, "greeting.SelectAvailableQuest 1"), 1)

    -- the hand-in is yours: not opened from the list, not continued, not completed
    env.now = env.now + 10
    env.gossip.active, env.gossip.available = { { questID = 219, title = "Missing In Action", isComplete = true } }, {}
    env.fire("GOSSIP_SHOW")
    equal(count(env, "gossip.SelectActiveQuest"), 0)
    env.quest = { id = 219, title = "Missing In Action", completable = true }
    env.fire("QUEST_PROGRESS")
    env.fire("QUEST_COMPLETE")
    equal(count(env, "CompleteQuest"), 0)
    equal(count(env, "GetQuestReward"), 0)

    -- a quest that is no escort and not repeatable is still nobody's business
    escortNPC(env, 783, "A Threat Within")
    equal(count(env, "gossip.SelectAvailableQuest 783"), 0)
    -- ... nor is the long event in Blackrock Depths, which is left off the list on purpose
    escortNPC(env, 4322, "Jail Break!")
    equal(count(env, "gossip.SelectAvailableQuest 4322"), 0)
    check(env.ns.Quests.escorts[219] and env.ns.Quests.escorts[1144] and not env.ns.Quests.escorts[4322] and not env.ns.Quests.escorts[3525])
end)

scenario("the escort inside Razorfen Downs is never started and never joined: in the list, at its offer, when the game calls it repeatable, when someone in the party starts it", function()
    local env = start({ repeatable = { [3525] = true } })
    escortNPC(env, 3525, "Extinguishing the Idol", { repeatable = true })
    equal(count(env, "gossip.SelectAvailableQuest"), 0)
    check(env.AKForeverFastTurninDB.log[1].text:find("never started for you", 1, true), env.AKForeverFastTurninDB.log[1].text)
    env.quest = { id = 3525, title = "Extinguishing the Idol" }
    env.fire("QUEST_DETAIL")
    equal(count(env, "AcceptQuest"), 0)
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Extinguishing the Idol", 3525)
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Extinguishing the Idol") -- a client that does not give the number
    equal(count(env, "ConfirmAcceptQuest"), 0)
    equal(count(env, "StaticPopup_Hide"), 0)
    -- its hand-in is left alone as well
    env.gossip.active, env.gossip.available = { { questID = 3525, title = "Extinguishing the Idol", isComplete = true, repeatable = true } }, {}
    env.fire("GOSSIP_SHOW")
    equal(count(env, "gossip.SelectActiveQuest"), 0)
    env.slash("log")
    check(printed(env, "Extinguishing the Idol (3525): left alone - this one is never started for you"), table.concat(env.printed, " | "))
end)

scenario("someone in the party starts an escort: you join without a click and the game's question goes away", function()
    local env = start()
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Missing In Action", 219)
    equal(count(env, "ConfirmAcceptQuest"), 1)
    equal(count(env, "StaticPopup_Hide QUEST_ACCEPT"), 1)
    check(env.AKForeverFastTurninDB.log[1].text:find("Missing In Action (219): joined - Purr Rogie started it", 1, true), env.AKForeverFastTurninDB.log[1].text)

    -- any quest the game asks this about, on the escort list or not; the number missing, the name does
    env.now = env.now + 10
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Jail Break!", 4322)
    env.now = env.now + 10
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "The Attack!")
    equal(count(env, "ConfirmAcceptQuest"), 3)

    -- the same question twice in a moment is answered once
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "The Attack!")
    equal(count(env, "ConfirmAcceptQuest"), 3)

    -- Shift held: yours to answer
    env.now = env.now + 10
    env.shift = true
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Missing In Action", 219)
    equal(count(env, "ConfirmAcceptQuest"), 3)
    env.shift = false

    -- a client without the dialog call: joined all the same
    local bare = start({ without = { "StaticPopup_Hide" } })
    bare.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Missing In Action", 219)
    equal(count(bare, "ConfirmAcceptQuest"), 1)

    -- which quest it is kept secret: it could be the one that is never joined, so nothing is answered
    local SECRET = {}
    local hidden = start({ secret = SECRET })
    hidden.fire("QUEST_ACCEPT_CONFIRM", SECRET, SECRET, SECRET)
    equal(count(hidden, "ConfirmAcceptQuest"), 0)
    hidden.fire("QUEST_ACCEPT_CONFIRM", SECRET, "Missing In Action", SECRET) -- the name alone is enough to know
    equal(count(hidden, "ConfirmAcceptQuest"), 1)
end)

scenario("'/akft escorts off' leaves every escort to you, starting and joining, and is kept for next time; the hand-ins go on", function()
    local env = start({ items = { [248765] = 1 } })
    env.slash("escorts off")
    check(printed(env, "escorts: off"), table.concat(env.printed, " | "))
    escortNPC(env, 219, "Missing In Action")
    equal(count(env, "gossip.SelectAvailableQuest"), 0)
    env.quest = { id = 219, title = "Missing In Action" }
    env.fire("QUEST_DETAIL")
    equal(count(env, "AcceptQuest"), 0)
    env.fire("QUEST_ACCEPT_CONFIRM", "Purr Rogie", "Missing In Action", 219)
    equal(count(env, "ConfirmAcceptQuest"), 0)
    -- a sealed crate still goes
    dokimi(env)
    env.talk()
    equal(env.handed, 1)

    local again = start({ db = env.AKForeverFastTurninDB })
    escortNPC(again, 219, "Missing In Action")
    equal(count(again, "gossip.SelectAvailableQuest"), 0)
    again.slash("escorts on")
    check(printed(again, "escorts: on"))
    escortNPC(again, 219, "Missing In Action")
    equal(count(again, "gossip.SelectAvailableQuest 219"), 1)
    again.slash("")
    check(printed(again, "/akft escorts"), "the status names the switch")
end)

print(string.format("\n%d passed, %d failed", passed, #failures))
if #failures > 0 then
    os.exit(1)
end
