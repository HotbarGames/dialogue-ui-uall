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

<!-- claude-config:dependency-safety START (managed by claude-config; do not edit between the markers — claude-sync.sh keeps this block in step across projects) -->
## Dependency safety (supply-chain)

Enforced by `.claude/hooks/check-install-safety.sh` and binding on every install command you
**run** OR **write into** a script, workflow, doc, Dockerfile, or CI file:

1. **Pin an exact version.** Never `@latest`/`@next`/`@beta` or a floating range (`^ ~ >= *`).
   `npm install pkg@1.2.3 --save-exact --ignore-scripts` · `pip install pkg==1.2.3`.
2. **Cool-down ≥ 14 days.** Only use versions published at least two weeks ago, so a malicious
   release has time to be caught and pulled.
3. **Never fetch-and-run remote code.** No `curl … | sh`, no `npx`/`bunx`/`uvx -y` or `pnpm/yarn dlx`
   of a remote package, no `pip install` from a URL / `git+` / VCS.
4. **Block install scripts.** Pass `--ignore-scripts` on npm/pnpm/yarn/bun installs (postinstall is
   the main npm payload vector). Prefer lockfile installs (`npm ci`, pinned `requirements.txt`) and
   run `npm audit` after adding deps.

Deliberate, reviewed exception only: prefix the one command with `ALLOW_UNSAFE_INSTALL=1` and state why.
<!-- claude-config:dependency-safety END -->

<!-- claude-config:context-economy START (managed by claude-config; do not edit between the markers — claude-sync.sh keeps this block in step across projects) -->
## Context economy (token discipline)

Every line you author or load is paid for by every future reader, human or model. Spend deliberately.

- **The cost is the whole bundle a reader must load to answer, not the file in view.** Every size check in this toolchain counts one file, so splitting relocates cost rather than removing it — when you split, report the bundle total beside the per-file number.
- **Read the slice, not the file** when you need only a part; delegate bulk or many-file reads to a subagent and keep only its conclusion. Fidelity outranks cheapness — nothing here caps a legitimate full read.
- **Externalize scratch.** Write intermediate results and working notes to disk (a scratchpad), not into the conversation.
- **Project, don't append-scan.** For big append-only docs, keep a top-of-file index/ledger and read that first; drill into full entries only when needed.

`.claude/hooks/context-economy.sh` owns the thresholds and surfaces non-blocking nudges on oversized writes and full loads of large files. Silence with `CONTEXT_ECONOMY_OFF=1`.
<!-- claude-config:context-economy END -->
