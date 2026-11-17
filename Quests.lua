-- AKForeverFastTurnin - the quests that are always clicked through. Written by tools/gen_quests.py;
-- do not edit (see that file for where each fact comes from).
local _, ns = ...

ns.Quests = {
    -- [quest id] = { item = the sealed crate it wants, name = that crate's name, confirmed = the item
    -- id was read from a quest database (false: it follows the numbering of the others) }
    sealed = {
        [91899] = { item = 248765, name = "Sealed Apprentice Crate", confirmed = true },
        [91900] = { item = 248766, name = "Sealed Journeyman Crate", confirmed = true },
        [91901] = { item = 248767, name = "Sealed Expert Crate", confirmed = false },
        [91902] = { item = 248768, name = "Sealed Artisan Crate", confirmed = false },
        [91904] = { item = 248770, name = "Sealed Apprentice Crate", confirmed = true },
        [91905] = { item = 248771, name = "Sealed Journeyman Crate", confirmed = true },
        [91906] = { item = 248772, name = "Sealed Expert Crate", confirmed = false },
        [91907] = { item = 248773, name = "Sealed Artisan Crate", confirmed = false },
    },
    -- Craftsman's Writ quests (150, from AKForeverCrateCost's data of 2026-11-14)
    writs = {
        [94004] = true, [94212] = true, [94213] = true, [94214] = true, [94215] = true, [94216] = true, [94217] = true, [94218] = true, [94219] = true, [94220] = true,
        [94221] = true, [94222] = true, [94223] = true, [94224] = true, [94225] = true, [94226] = true, [94227] = true, [94228] = true, [94229] = true, [94230] = true,
        [94231] = true, [94232] = true, [94233] = true, [94234] = true, [94235] = true, [94236] = true, [94237] = true, [94238] = true, [94239] = true, [94240] = true,
        [94241] = true, [94242] = true, [94243] = true, [94244] = true, [94245] = true, [94246] = true, [94247] = true, [94248] = true, [94249] = true, [94250] = true,
        [94251] = true, [94252] = true, [94253] = true, [94254] = true, [94255] = true, [94256] = true, [94257] = true, [94258] = true, [94259] = true, [94260] = true,
        [94261] = true, [94262] = true, [94263] = true, [94264] = true, [94265] = true, [94266] = true, [94267] = true, [94268] = true, [94269] = true, [94270] = true,
        [94271] = true, [94272] = true, [94273] = true, [94274] = true, [94275] = true, [94276] = true, [94277] = true, [94278] = true, [94279] = true, [94280] = true,
        [94281] = true, [94282] = true, [94283] = true, [94284] = true, [94285] = true, [94286] = true, [94287] = true, [94288] = true, [94289] = true, [94290] = true,
        [94291] = true, [94292] = true, [94293] = true, [94294] = true, [94295] = true, [94296] = true, [94297] = true, [94298] = true, [94299] = true, [94300] = true,
        [94301] = true, [94302] = true, [94303] = true, [94304] = true, [94305] = true, [94306] = true, [94307] = true, [94308] = true, [94309] = true, [94310] = true,
        [94311] = true, [94312] = true, [94313] = true, [94314] = true, [94315] = true, [94316] = true, [94317] = true, [94318] = true, [94319] = true, [94320] = true,
        [94321] = true, [94322] = true, [94323] = true, [94324] = true, [94325] = true, [94326] = true, [94327] = true, [94328] = true, [94329] = true, [94330] = true,
        [94331] = true, [94332] = true, [94333] = true, [94334] = true, [94335] = true, [94336] = true, [94337] = true, [94338] = true, [94339] = true, [94340] = true,
        [94341] = true, [94342] = true, [94343] = true, [94344] = true, [94345] = true, [94346] = true, [94347] = true, [94348] = true, [94349] = true, [94350] = true,
        [94351] = true, [94352] = true, [94353] = true, [94354] = true, [94355] = true, [94356] = true, [94357] = true, [94358] = true, [94359] = true, [94360] = true,
    },
    -- Escorts: started for you, handed in by you (45)
    escorts = {
        [155] = true, -- The Defias Brotherhood
        [219] = true, -- Missing In Action
        [309] = true, -- Protecting the Shipment
        [435] = true, -- Escorting Erland
        [648] = true, -- Rescue OOX-17/TN!
        [660] = true, -- Hints of a New Plague?
        [665] = true, -- Sunken Treasure
        [667] = true, -- Death From Below
        [731] = true, -- The Absent Minded Prospector
        [836] = true, -- Rescue OOX-09/HL!
        [863] = true, -- The Escape
        [898] = true, -- Free From the Hold
        [938] = true, -- Mist
        [945] = true, -- Therylune's Escape
        [976] = true, -- Supplies to Auberdine
        [994] = true, -- Escape Through Force
        [995] = true, -- Escape Through Stealth
        [1144] = true, -- Willix the Importer
        [1222] = true, -- Stinky's Escape
        [1270] = true, -- Stinky's Escape
        [1393] = true, -- Galen's Escape
        [1440] = true, -- Return to Vahlarriel
        [1560] = true, -- Tooga's Quest
        [1651] = true, -- The Tome of Valor
        [2742] = true, -- Rin'ji is Trapped!
        [2767] = true, -- Rescue OOX-22/FE!
        [2845] = true, -- Wandering Shay
        [2904] = true, -- A Fine Mess
        [3367] = true, -- Suntara Stones
        [3382] = true, -- A Crew Under Fire
        [4121] = true, -- Precarious Predicament
        [4245] = true, -- Chasing A-Me 01
        [4261] = true, -- Ancient Spirit
        [4491] = true, -- A Little Help From My Friends
        [4770] = true, -- Homeward Bound
        [4904] = true, -- Free at Last
        [4966] = true, -- Protect Kanati Greycloud
        [5203] = true, -- Rescue From Jaedenar
        [5321] = true, -- The Sleeper Has Awakened
        [5713] = true, -- One Shot.  One Kill.
        [5821] = true, -- Bodyguard for Hire
        [5943] = true, -- Gizelton Caravan
        [6132] = true, -- Get Me Out of Here!
        [6482] = true, -- Freedom to Ruul
        [6523] = true, -- Protect Kaya
    },
    -- Never started and never joined for you: [quest id] = its name (for a client that names the
    -- quest without its number)
    never = {
        [3525] = "Extinguishing the Idol",
    },
}
