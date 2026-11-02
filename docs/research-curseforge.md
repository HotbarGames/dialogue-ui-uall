# Publishing "Dialogue UI - UALL" on CurseForge (WoW Forever), researched 2026-11-01

Sources are primary (CurseForge support / author docs, CurseForge's own blog, the BigWigsMods/packager README, wiki and `release.sh`, warcraft.wiki.gg for TOC). Anything not confirmed by a source is marked **UNVERIFIED**.

Context: WoW Forever patch 1.60.1 = interface **16001**. CurseForge already has a **"Forever"** flavor: UALL Forever's files are tagged game version **1.60.1**, flavor **Forever** (https://www.curseforge.com/wow/addons/uall-forever-ukrainian-localization/files). The CurseForge app added "Support for the 'Forever' beta flavor" on 2026-09-22 (https://blog.curseforge.com/app-release-notes-1-321/).

## 1. Project creation (author console)

Start at https://authors.curseforge.com/#/projects/create/choose-game. Source for the fields: "Creating and submitting a project", https://support.curseforge.com/en/support/solutions/articles/9000197241-creating-and-submitting-a-project

| Field | What the sources say |
|---|---|
| **Name** | Must be unique (rejected if taken). Must be in English. Should not contain the game name, class name or version numbers: "Names should not contain game name, class name versions, file versions" (moderation policy, https://support.curseforge.com/en/support/solutions/articles/9000197279). The blog adds: leave out category words such as "Mod" (https://blog.curseforge.com/how-to-pass-moderation-review-on-curseforge-2/). Max length: **UNVERIFIED**. |
| **Summary** | Short blurb shown in listings, "preferably no longer than 1 sentence", describe what it does, not who made it or who it's for; don't copy the description (9000197279, 9000197241). Hard character limit: **UNVERIFIED** (no source states one; the form will show it). |
| **Description** | Two editors: **WYSIWYG (default) or Markdown**; no BBCode mentioned ("Project Submission Guide and Tips", https://support.curseforge.com/support/solutions/articles/9000199552). Images/videos can be embedded. Must explain functionally what the addon does; English first if other languages are included (9000197279). Description problems are "by far the most common reason for requesting changes" (blog). |
| **Class / categories** | Class = Addons. One **main category** plus **up to 4 additional**; irrelevant categories get the project sent back (9000197241). WoW category list (https://www.curseforge.com/wow/addons): Achievements, Action Bars, Artwork, Auction & Economy, Audio & Video, Bags & Inventory, Boss Encounters, Buffs & Debuffs, Camping, Chat & Communication, Class (+subclasses), Combat, Companions, Data Export, Development Tools, Garrison, Guild, Housing, Libraries, Mail, Map & Minimap, Minigames, Miscellaneous, Plugins (Data Broker, FuBar, Titan Panel), Professions, PvP, Quests & Leveling, Roleplay, Tooltip, Twitch Integration, Unit Frames. **There is no "Localization/Translation" category.** For our bridge: main **Quests & Leveling** (same as Dialogue UI), additional **Miscellaneous** (UALL Forever uses Miscellaneous only). "Plugins" only has Data Broker/FuBar/Titan subcategories, so it does not fit. |
| **License** | Dropdown of "common modding licenses" plus **Custom License** at the bottom (9000197241). Exact list (whether "MIT License" is an entry) **UNVERIFIED**; if MIT is missing, pick Custom and paste LICENSE.txt. Both Dialogue UI and UALL Forever are **All Rights Reserved**. Separate **"Project Distribution Toggle"** on the create page / License tab, default **on** (allows third-party apps/API to serve the files; off = not in 3rd-party API) (https://support.curseforge.com/support/solutions/articles/9000207877). |
| **Game version / flavor** | Not chosen at project level; chosen **per file** on upload ("Supported Version", 9000197241). Flavor filter labels on the site: Retail, Classic, Classic TBC, MoP Classic, WotLK Classic, **Forever**, Cataclysm Classic, Titan Reforged Classic. On upload you tick the game version **1.60.1** (Forever). The exact upload-form label (e.g. "Forever 1.60.1" vs grouped under a "Forever" heading) is **UNVERIFIED**. |
| **Logo / avatar** | "All avatars need to be **400x400 pixels**" (so 1:1); avoid **WebP** (known bug). Must be original: no solid single colour, no copyrighted/unlicensed assets, no copy of another project's avatar (9000197279; blog). PNG is the safe format (`publish/logo/logo-400.png` fits). Max file size **UNVERIFIED**. Note: a logo copying Dialogue UI's artwork would break the "no someone else's assets without permission" rule. |
| **Screenshots / gallery** | Images tab after creation; title + description per image. Required only for texture packs / visual projects / Sims, **not for addons** (9000197241, 9000197279). Recommended anyway (in-game screenshot of Ukrainian text in Dialogue UI). AI-altered showcase images need a visible disclaimer (9000197279). |

## 2. File upload

- **Archive**: must be a real **.zip** (not a renamed .rar), < 2 GB (9000197241).
- **Layout**: TOC name must match its parent folder: "Every TOC file needs to start with the addon name used in the parent folder", otherwise "the CurseForge validator may fail the upload" (Multi-TOC article, https://support.curseforge.com/support/solutions/articles/9000209856-multi-toc-for-world-of-warcraft-addons). So the zip must contain a top-level folder `DialogueUI_UALL/` holding `DialogueUI_UALL.toc` and the rest (the packager also builds it this way: `package-as` "sets the root directory name"). That the validator *requires* the top-level folder (versus files at the zip root) is implied, not stated explicitly: **partly UNVERIFIED**.
- **Game version per file**: ticked manually on upload ("you can tag which versions are supported", editable later; 9000209856). Via API: `gameVersions` array of IDs from `GET https://wow.curseforge.com/api/game/versions` (CurseForge Upload API, https://support.curseforge.com/en/support/solutions/articles/9000197321). The packager uses version type id **88568 for forever** (`release.sh`, https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh).
- **Release type**: Release / Beta / Alpha. Only Release auto-downloads by default, and "Projects must have at least one 'Release' file before they sync to the CurseForge App" (9000197241).
- **Changelog**: required by policy ("Files must include a change log describing the changes from the previous version", 9000197279). Format: API `changelogType` = `text`, `html` or `markdown` (9000197321). Web form format **UNVERIFIED** (likely the same editor choice).
- **Display name**: optional, defaults to file name. Optional delayed/manual release toggle (9000197241; API `isMarkedForManualRelease`).
- **Relations** (per file, "Related Projects": required dependencies, recommended projects, incompatibilities; required ones "automatically downloaded in the client", 9000197241). API types: `requiredDependency`, `optionalDependency`, `embeddedLibrary`, `tool`, `incompatible` (9000197321). For us, add two **Required Dependency** relations by project slug:
  - Dialogue UI: slug `dialogueui`, project ID 989270 (https://www.curseforge.com/wow/addons/dialogueui)
  - UALL Forever: slug `uall-forever-ukrainian-localization`, project ID 1724481
  Both projects publish Forever files, so the app can resolve them for Forever.

## 3. Moderation

- Flow: upload, file shows "Under Review", moderators approve, request changes or reject, with a reason; fix and resubmit or appeal via ticket; don't delete and re-upload (9000197241; blog). Layers: automated (malware, executables like .exe/.sh/.bat, duplicates, forbidden/reserved keywords), then manual (page text, images, tags), then community reports (https://docs.curseforge.com/docs/capabilities/moderation/overview, a studio-facing page, but describes the same pipeline).
- **Review time: no official figure (UNVERIFIED)**. The only numbers: team reviews "around 2,000 new projects a week" (blog, 2025-02-09); support tickets answered in 48-72 h (not moderation). Plan for a few days for the first (project) review; updates are usually faster (**UNVERIFIED**).
- Common rejection reasons in the sources: weak/ungrammatical/vague description; generic name or name with metadata (version, game name, "mod"); non-original avatar; irrelevant categories; missing changelog; unlicensed fork or re-upload ("Re-uploading a project as-is is prohibited unless the owner explicitly permits it"); copyrighted content without permission; external download links. **Obfuscation and third-party code**: no CurseForge policy text found (**UNVERIFIED**); keep code readable, and bundle no code or data from Dialogue UI / UALL (both ARR, which means explicit permission needed: blog).
- **Naming after other projects**: no CurseForge rule found that forbids or allows naming an add-on after the host projects (**UNVERIFIED**). What applies: name must be unique and "distinct" (9000197279), English, no version numbers. Precedent: third-party add-ons named after their host are common and approved, e.g. "ElvUI WindTools" by fang2hou (https://www.curseforge.com/wow/addons/elvui-windtools). "Dialogue UI - UALL" is unique and descriptive, so likely fine. Risk reducers: in the summary/description say plainly it is an unofficial bridge, not made by Peterodox/Raenore or Pekelnyj/ne_multik, credit and link both projects, and don't reuse their logos. Asking both authors (courtesy, and they could otherwise report it as confusing) is advisable but not a documented requirement. Note the name contains no game name ("WoW") or version, which the policy forbids.

## 4. .pkgmeta / BigWigs packager (for later automation)

Minimal `.pkgmeta` (syntax from https://raw.githubusercontent.com/wiki/BigWigsMods/packager/Preparing-the-PackageMeta-File.md; dependency values are CurseForge **slugs**):

```yaml
package-as: DialogueUI_UALL

required-dependencies:
  - dialogueui
  - uall-forever-ukrainian-localization

manual-changelog:
  filename: CHANGELOG.md
  markup-type: markdown

ignore:
  - README.md
```

- The packager maps `required-dependencies` to `requiredDependency` relations in the upload metadata, `optional-dependencies` to `optionalDependency`, etc. (`release.sh`).
- Game version detection: from `## Interface:`; `16???` maps to game type `forever` (CF version type 88568). Interface 16001 → 1.60.1. Caution: our TOC also lists `120100`, so the packager would also tag a **Retail** version; drop it if the release is Forever-only. The packager knows the split-TOC suffix `_Camelot` but not yet `_Forever` (`release.sh`); the client accepts both since 1.60.1 Beta (https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes). A single TOC with comma-separated interfaces avoids the issue.
- GitHub Actions (wiki "GitHub Actions workflow"): trigger on tag push, `actions/checkout` with `fetch-depth: 0`, `uses: BigWigsMods/packager@v2`, secret passed as env. README names the env var `CF_API_TOKEN` (token from https://authors.curseforge.com/#/settings/api-tokens); `CF_API_KEY` still works but is marked deprecated in `release.sh`.
- **X-Curse-Project-ID belongs in the TOC**: README: set the project id with `-p` "or by adding the following to the TOC file: `## X-Curse-Project-ID: 1234`" (ID is in the "About Project" box). It only exists after the project is created, so add it afterwards. Harmless to the game client (X- fields are ignored except via `C_AddOns.GetAddOnMetadata`).
- The first file can be uploaded by hand; the packager is optional.

## 5. TOC fields

Source: https://warcraft.wiki.gg/wiki/TOC_format (community wiki, the de-facto reference; Blizzard publishes no TOC docs).

| Field | Recommendation |
|---|---|
| `## Category:` | Real field (added in 11.1.0): collapsible header in the AddOn list; "strongly recommended" to use the translated names from the Addon Categories page; localize with `## Category-ukUA:` *after* the plain one. Our TOC has `## X-Category: Localization`, which is only custom metadata and does **nothing** in the client. Use `## Category:` if wanted. Support in the Forever client: likely (Forever is in the Mainline family) but **UNVERIFIED**. |
| `## Group:` | Groups an addon under a main addon in the AddOn list; value = main addon's folder name, e.g. `## Group: DialogueUI`. The client may infer it automatically when one name is a prefix of the other and there is a dependency (`DialogueUI_UALL` starts with `DialogueUI` and depends on it). Optional; only add with the main addon's agreement in mind (it nests us under their entry). Forever support **UNVERIFIED**. |
| `## IconTexture:` | Fine (since 10.1.0): icon in the AddOn list. Ours points to `Interface\AddOns\DialogueUI_UALL\Logo`. |
| `## X-Website:` | Optional custom field, shown by some managers; recommended once the CurseForge/GitHub URL exists. |
| `## X-Curse-Project-ID:` | Recommended only for packager automation (see section 4). Not needed by CurseForge for manual uploads. |
| `## X-License:` | Custom, harmless. |

CurseForge itself requires none of these; its only TOC requirements found are matching folder/TOC names and a correct `## Interface` (9000209856).

## Checklist before upload

- [ ] Zip = `DialogueUI_UALL/` folder containing `DialogueUI_UALL.toc`, `Core.lua`, `LICENSE.txt`, `Logo.png`; real .zip; no .exe/.bat/.sh; no files from Dialogue UI or UALL.
- [ ] TOC `## Interface` matches what you tag: Forever-only → `16001` (consider dropping `120100` unless Retail is really supported). Replace `## X-Category` with `## Category` if you want the header.
- [ ] Project: name `Dialogue UI - UALL` (English, no version, no "WoW"); one-sentence English summary; English description first (Ukrainian after), stating it is an unofficial bridge, crediting and linking both projects and authors, with `/duall` usage.
- [ ] Categories: main Quests & Leveling, extra Miscellaneous.
- [ ] License: MIT (or Custom with LICENSE text if MIT not in the list); decide the distribution toggle (default on).
- [ ] Logo: original 400x400 PNG (not WebP), not derived from Dialogue UI's logo artwork.
- [ ] Optional screenshot in Images tab.
- [ ] File: release type Release, game version Forever 1.60.1, changelog filled in.
- [ ] Relations: Required Dependency `dialogueui` and `uall-forever-ukrainian-localization`.
- [ ] Optional courtesy message to Peterodox/Raenore and Pekelnyj/ne_multik.
- [ ] After approval: add `## X-Curse-Project-ID` (and `## X-Website`) to the TOC if automating with BigWigs packager.
