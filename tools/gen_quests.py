# Writes Quests.lua: the quests AKForeverFastTurnin always clicks through, whatever the game says about
# them being repeatable. Run from the repo root:  python tools/gen_quests.py
#
#   * The eight "A Sealed Crate" quests - hand-written below, each with where the fact comes from.
#   * The Craftsman's Writ quests - read from AKForeverCrateCost's Data.lua (the folder next to this
#     repo), which its own tools/build_data.mjs writes from Wowhead's tooltips. Run this again after
#     that file is rebuilt.
#   * The escorts that are STARTED for you (never handed in) and the one that never is - hand-written
#     below, with where they come from.
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CRATECOST = os.path.join(os.path.dirname(ROOT), "AKForeverCrateCost", "Data.lua")

# quest id, the sealed crate it wants, its name, confirmed?
#   Quest ids and names: Wowhead's quest pages, read 2026-11-14 for AKForeverCrateCost
#   (tools/overrides.json there). Offered and taken back by NPC 256386 (Dokimi, The Barrens) and NPC
#   256390 (the Alliance's intake, Redridge Mountains): the installed QuestieDB, read 2026-11-16.
#   Items: QuestieDB lists the crate for four of the eight (confirmed = True). The other four follow
#   the same numbering (item = quest + 156866) and are NOT confirmed - the addon also looks for those
#   crates by name.
SEALED = [
    (91899, 248765, "Sealed Apprentice Crate", True),
    (91900, 248766, "Sealed Journeyman Crate", True),
    (91901, 248767, "Sealed Expert Crate", False),
    (91902, 248768, "Sealed Artisan Crate", False),
    (91904, 248770, "Sealed Apprentice Crate", True),
    (91905, 248771, "Sealed Journeyman Crate", True),
    (91906, 248772, "Sealed Expert Crate", False),
    (91907, 248773, "Sealed Artisan Crate", False),
]

# Escorts: quests that begin the moment they are accepted - an NPC to walk with or to stand by - and
# that the game offers to the rest of the party when one member starts them.
#   From the installed QuestieDB, read 2026-11-16: quests flagged PARTY_ACCEPT (questFlags bit 2) whose
#   objective is an event to escort, protect, defend, rescue or lead someone. The flag alone is far wider
#   (battleground quests, Triage, stories to listen to): those are not here.
#   Left out on purpose: 4322 Jail Break! (Blackrock Depths) - a long event a group prepares for; it is
#   not started for you, but joining it when a party member starts it works like any other.
ESCORTS = [
    (155, "The Defias Brotherhood"), (219, "Missing In Action"), (309, "Protecting the Shipment"),
    (435, "Escorting Erland"), (648, "Rescue OOX-17/TN!"), (660, "Hints of a New Plague?"),
    (665, "Sunken Treasure"), (667, "Death From Below"), (731, "The Absent Minded Prospector"),
    (836, "Rescue OOX-09/HL!"), (863, "The Escape"), (898, "Free From the Hold"), (938, "Mist"),
    (945, "Therylune's Escape"), (976, "Supplies to Auberdine"), (994, "Escape Through Force"),
    (995, "Escape Through Stealth"), (1144, "Willix the Importer"), (1222, "Stinky's Escape"),
    (1270, "Stinky's Escape"), (1393, "Galen's Escape"), (1440, "Return to Vahlarriel"),
    (1560, "Tooga's Quest"), (1651, "The Tome of Valor"), (2742, "Rin'ji is Trapped!"),
    (2767, "Rescue OOX-22/FE!"), (2845, "Wandering Shay"), (2904, "A Fine Mess"), (3367, "Suntara Stones"),
    (3382, "A Crew Under Fire"), (4121, "Precarious Predicament"), (4245, "Chasing A-Me 01"),
    (4261, "Ancient Spirit"), (4491, "A Little Help From My Friends"), (4770, "Homeward Bound"),
    (4904, "Free at Last"), (4966, "Protect Kanati Greycloud"), (5203, "Rescue From Jaedenar"),
    (5321, "The Sleeper Has Awakened"), (5713, "One Shot.  One Kill."), (5821, "Bodyguard for Hire"),
    (5943, "Gizelton Caravan"), (6132, "Get Me Out of Here!"), (6482, "Freedom to Ruul"), (6523, "Protect Kaya"),
]

# Never started and never joined for you, whatever else says so (the user, 2026-11-16: "make sure this
# does not work for the escort quest inside of RFD"): accepting it sets off the fight at the idol.
#   3525 Extinguishing the Idol, Belnistrasz in Razorfen Downs (QuestieDB: zone 722, PARTY_ACCEPT).
NEVER = [
    (3525, "Extinguishing the Idol"),
]


def writ_quests():
    text = io.open(CRATECOST, encoding="utf-8").read()
    start = text.index("writs = {")
    quests = sorted({int(n) for n in re.findall(r"quest = (\d+)", text[start:])})
    if len(quests) < 100:
        sys.exit("only %d writ quests found in %s - not writing" % (len(quests), CRATECOST))
    built = re.search(r'built = "([^"]+)"', text)
    return quests, built.group(1) if built else "?"


def main():
    quests, built = writ_quests()
    out = [
        "-- AKForeverFastTurnin - the quests that are always clicked through. Written by tools/gen_quests.py;",
        "-- do not edit (see that file for where each fact comes from).",
        "local _, ns = ...",
        "",
        "ns.Quests = {",
        "    -- [quest id] = { item = the sealed crate it wants, name = that crate's name, confirmed = the item",
        "    -- id was read from a quest database (false: it follows the numbering of the others) }",
        "    sealed = {",
    ]
    for quest, item, name, confirmed in SEALED:
        out.append('        [%d] = { item = %d, name = "%s", confirmed = %s },' % (quest, item, name, "true" if confirmed else "false"))
    out += [
        "    },",
        "    -- Craftsman's Writ quests (%d, from AKForeverCrateCost's data of %s)" % (len(quests), built),
        "    writs = {",
    ]
    for at in range(0, len(quests), 10):
        out.append("        " + " ".join("[%d] = true," % q for q in quests[at:at + 10]))
    out += [
        "    },",
        "    -- Escorts: started for you, handed in by you (%d)" % len(ESCORTS),
        "    escorts = {",
    ]
    for quest, name in ESCORTS:
        out.append("        [%d] = true, -- %s" % (quest, name))
    out += [
        "    },",
        "    -- Never started and never joined for you: [quest id] = its name (for a client that names the",
        "    -- quest without its number)",
        "    never = {",
    ]
    for quest, name in NEVER:
        out.append('        [%d] = "%s",' % (quest, name))
    out += ["    },", "}", ""]
    if {q for q, _ in ESCORTS} & {q for q, _ in NEVER}:
        sys.exit("a quest is on both the escort list and the never list - not writing")
    io.open(os.path.join(ROOT, "Quests.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("Quests.lua: %d sealed crate quests, %d writ quests, %d escorts, %d never" % (len(SEALED), len(quests), len(ESCORTS), len(NEVER)))


main()
