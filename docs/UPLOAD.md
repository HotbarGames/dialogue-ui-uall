# Publishing "Dialogue UI - UALL" on CurseForge

Background and sources: `research-curseforge.md`. Forever goes live on 4 Nov 2026, 23:00 UTC (01:00 on 5 Nov in
Kyiv). Before uploading: test on Forever (`TESTING.md`), and check that Forever's interface number is still 16001
(`/dump select(4, GetBuildInfo())` in game); if it changed, add the new number to the TOC's `## Interface` first.

## 1. Build the file

    python3 tools/make_zip.py        # -> dist/DialogueUI_UALL-<version>.zip

The zip holds one folder, `DialogueUI_UALL/` (toc, Core.lua, Window.lua, Logo.tga, LICENSE.txt, CHANGELOG.md).

## 2. Create the project (authors.curseforge.com → Create Project → World of Warcraft)

| Field | Value |
|---|---|
| Name | Dialogue UI - UALL (the slug should become `dialogue-ui-uall`: the install links below use it; if it differs, replace it in `curseforge-description.md`, both READMEs and the video description) |
| Summary | Dialogue UI's quest and NPC window in Ukrainian, using UALL Forever's translations. / Вікно завдань і розмов Dialogue UI українською — з перекладами UALL Forever. |
| Description | `curseforge-description.md` (Markdown editor). The before/after image link points at the GitHub repo, which works only once the repo is public; until then upload `media/before-after.png` in the editor instead |
| Main category | Quests & Leveling |
| Extra category | Miscellaneous |
| License | MIT (if missing from the list: Custom, paste `DialogueUI_UALL/LICENSE.txt`) |
| Avatar | `logo/logo-400.png` (400x400 PNG) |
| Links | Donate: `https://www.patreon.com/hotbar`. Source and Issues: `https://github.com/HotbarGames/dialogue-ui-uall` (`/issues`), only once the repo is public |
| Images (gallery) | In this order: `media/before-after.png` (quest window, English → Ukrainian), `media/gallery-2-quest-ua.png` (quest window), `media/gallery-1-gossip-ua.png` (NPC talk), `media/gallery-3-before-after-gossip.png` (NPC talk, English → Ukrainian). Real in-game screenshots; other players' names blurred |

## 3. Upload the file

| Field | Value |
|---|---|
| File | `dist/DialogueUI_UALL-1.0.0.zip` |
| Display name | Dialogue UI - UALL 1.0.0 |
| Release type | Release (a project needs one Release file to show in the app) |
| Game version | Forever 1.60.1 (the flavor list is rechecked on launch day) |
| Changelog | the 1.0.0 section of `DialogueUI_UALL/CHANGELOG.md` (Markdown; English, then the Ukrainian line) |
| Relations | Required Dependency: `dialogueui`; Required Dependency: `uall-forever-ukrainian-localization`; Optional Dependency: `uall-forever-ukrainian-quest-voiceover-levels-140` |

Required dependencies are what makes the one-click install bring Dialogue UI and UALL Forever along.

## 4. After approval

- Open `https://www.curseforge.com/wow/addons/dialogue-ui-uall/install` once on the PC with the Forever client:
  it should install all three addons into `_forever_`.
- Add `## X-Curse-Project-ID: <id>` to the TOC (needed for `.github/workflows/release.yml`, which uploads a
  tagged release; it also needs the `CF_API_TOKEN` repo secret).
- Video: post the short (`media/short-ua.mp4`, cover `media/short-cover.png`) on TikTok, YouTube Shorts and Instagram Reels, and the explainer (`media/promo-ua.mp4` or the 1080p render) as a YouTube video; texts, timing and settings are in `media/video-description.md`. Post only once the project is approved and found by name. Add the YouTube link to the CurseForge page.
- Send the courtesy notes to the UALL team and the Dialogue UI authors (drafts are kept privately, not in this
  repo). The UALL note also asks for permission to use their voice line in the video: only after a yes, publish
  the "with UALL voice" render.
- For every new version: bump `## Version` and `CHANGELOG.md` together, rebuild the zip, upload with the same
  relations (or push a `v*` tag once the release workflow is set up).
