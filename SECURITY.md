# Security

## Which version is supported

Only the latest release on CurseForge. Please check that the problem is still there in the latest release before
you report it.

## How to report a problem

Please report privately, not in a public issue:

1. Open the **Security** tab of this repository.
2. Click **Report a vulnerability**.
3. Say what you found and how to repeat it.

There is no email address. GitHub's private report is the only channel, and it keeps the report between you and the
maintainers until a fix is out.

## What counts

- the addon itself (`DialogueUI_UALL/`): anything that lets another player, a chat message or another addon make it
  run code, break the game's secure UI (taint that blocks actions), or write unexpected data into SavedVariables;
- the release: the zip built by `.github/workflows/release.yml` and `tools/make_zip.py` holding anything other than
  the files in `DialogueUI_UALL/`;
- `install.bat`: copying to or deleting from anywhere other than the chosen WoW `Interface\AddOns` folder.

Not in scope: problems in World of Warcraft, CurseForge or GitHub themselves, and problems in Dialogue UI or
UALL Forever (please report those to their authors). Wrong or missing translations are not security problems: open
a normal issue, or tell the UALL team if the text itself is wrong.

## Known

- The addon only reads and writes text on Dialogue UI's window and on hidden Blizzard quest and gossip text fields
  (see the headers of `DialogueUI_UALL/Core.lua` and `DialogueUI_UALL/Window.lua`). It makes no network requests
  (WoW addons can't) and sends nothing anywhere.
- Its SavedVariables file (`DialogueUI_UALL.lua`) keeps only its version, status flags, the last 30 quest lookups
  (quest ID and title, which fields were found, window, time, error text) and up to 40 English lines UALL Forever
  had no translation for (first 80 characters each). Those NPC lines can contain your character's name, as NPCs say
  it; nothing else about your account or chat is stored.

## What to expect

- A first answer within about a week.
- If it is real, a fix in a new release, and a note in the changelog. You are credited if you like.
- Please give us time to fix it before you tell anyone else.

This is a hobby project, so there is no bounty.
