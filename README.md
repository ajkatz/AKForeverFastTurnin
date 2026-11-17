# AKForeverFastTurnin

World of Warcraft: Forever. The clicks of a repeatable hand-in, made for you.

Talk to Dokimi with a sealed crate in your bags and it is handed in: no quest list, no Accept, no
Continue, no Complete Quest. One talk per crate - the game closes the NPC's window after each hand-in, and
an addon cannot talk to an NPC for you.

## What it clicks through

- **Sealed crates.** The eight "A Sealed Crate" quests at the intake NPC (Dokimi west of the Crossroads, or
  the Alliance's in Redridge Mountains). A crate's quest is only accepted when that crate is in your bags,
  so your quest log is never filled with crates you do not have.
- **Craftsman's Writs.** Accepted when you open the writ, handed in when you talk to its customer.
- **Any quest the game calls repeatable**, at any NPC.

Every other quest is left alone, every step of it.

## Escorts

- **Started for you.** Talk to an escort's NPC - Corporal Keeshan, the OOX robots, Willix, Tooga and some
  forty more (the list is in `Quests.lua`) - and the quest is picked and accepted, so the walk begins.
  Quests where you stand by someone while they are attacked count as well.
- **Joined for you.** When someone in your party starts one, the game's "would you like to as well?" is
  answered yes, so you are not left without the quest while the NPC walks off.
- **Handed in by you.** An escort's reward is never taken for you.
- **Never in Razorfen Downs.** "Extinguishing the Idol" is not started and not joined: accepting it sets
  off the fight at the idol. "Jail Break!" in Blackrock Depths is not started for you either (joining it
  works).
- `/akft escorts off` leaves every escort to you.

## Where it stops

- **Shift held** while you talk to the NPC: nothing is clicked.
- A **choice of rewards**: yours to make.
- A hand-in that **costs gold**.
- Anything that is **not complete** yet.
- A window that comes back without anything having happened (a full quest log, say) is tried once.

## Commands

| | |
|---|---|
| `/akft` | whether it is on, and the commands |
| `/akft off`, `/akft on` | switch it; kept between sessions |
| `/akft escorts off`, `/akft escorts on` | starting and joining escorts; kept between sessions |
| `/akft log` | what it did, what it left alone, and why |

## What is not known yet

- Whether the game calls the sealed crate and writ quests repeatable. It does not have to: those are on a
  list of their own (`Quests.lua`).
- The item numbers of the Expert and Artisan sealed crates follow the numbering of the others and are not
  confirmed; those crates are found by their English name as well.

## Data

`Quests.lua` is written by `python tools/gen_quests.py`: the sealed crate quests are listed there with
their sources, the writ quests come from AKForeverCrateCost's `Data.lua` (the folder next to this one),
the escorts and the one that is never started are listed by hand with theirs.

## Tests

`lua tests/run.lua`
