# Testing in the game

What to check before a release, on WoW Forever with Dialogue UI and UALL Forever installed.

## Install

Close the game, then run `install.bat` (or copy `DialogueUI_UALL` into
`World of Warcraft\_forever_\Interface\AddOns\`). For a test on another client: `install.bat _retail_ deps`
also copies UALL Forever from `_forever_` and adds that client's interface number to the installed copy only.
On Retail most quest IDs differ from Forever; Elwynn Forest quests 40, 47 and 62 (Goldshire) still match.

## Checks

1. `/duall` prints `підключено: так` and `UALLF: завантажено`.
2. Talk to a quest giver: the greeting, reply options, the quest names in the list and «Прощавай» are Ukrainian.
3. Open a quest: the window title, the text, «Цілі», «Нагороди», «Прийняти», «Відхилити» are Ukrainian; no
   English paragraphs under the Ukrainian ones.
4. Turn a quest in: the completion text and «Завершити завдання» (or English «Complete» if the label is too
   long for the button at your font size).
5. Dialogue UI's translator button (top right): left click switches the quest text to English and back; right
   click shows the English paragraphs too.
6. Hold UALL Forever's original-text key (Shift) while opening a quest: English. Switch off parts in UALL
   Forever's settings: those stay English here too.
7. Open a quest's details on the world map, close it, then talk to an NPC: the NPC's quest is shown, not the
   map's; the map's own text is still right when you reopen it.
8. No Lua errors (`/console scriptErrors 1`, or BugSack). `/reload` and log out once: the window works again.

`/duall test` with a quest window open shows which quest fields UALL Forever had. Texts it had no translation
for are listed in `WTF\Account\<ACCOUNT>\SavedVariables\DialogueUI_UALL.lua` (`window.missed`), written on
`/reload` or logout.
