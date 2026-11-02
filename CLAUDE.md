# dialogue-ui-uall

"Dialogue UI - UALL": a WoW Forever addon that shows Dialogue UI's quest/NPC window in Ukrainian with
UALL Forever's translations. Maintainer notes for this machine (paths, test runner, git setup) are in
`CLAUDE.local.md` (not in git).

- Read the headers of `DialogueUI_UALL/Core.lua` (quest text through Dialogue UI's public translator API)
  and `DialogueUI_UALL/Window.lua` (the rest of the window: wrappers on Dialogue UI's private methods,
  "oracles" on UALL Forever's hooks) before changing anything. Background with file:line: `docs/research-*.md`.
- No texts of our own: every Ukrainian word comes from UALL Forever; what it lacks stays English.
- Forever only. The TOC lists Forever's interface numbers; `install.bat` adds another client's number to the
  installed copy for testing (Retail, TBC Anniversary).
- Nothing may ask for money inside the addon (Blizzard's add-on policy): the Patreon link lives only in the
  README, the CurseForge page and `.github/FUNDING.yml`.
- Never commit third-party code, art or sound (Dialogue UI, UALL Forever, Blizzard), or personal data
  (character, realm or account names).
- Release: bump `## Version` in the TOC and `DialogueUI_UALL/CHANGELOG.md` together; `python3 tools/make_zip.py`;
  steps in `docs/UPLOAD.md`. Viewer-facing Ukrainian must be natural and never evoke Russia.
