# Making this repository public

The repository is private until the addon works in WoW Forever and is published on CurseForge. This file lists the
steps for that day, in order. Only section 1 has been done. Run the commands in WSL from the repository folder,
after `source ../.envrc` (it sets `GH_TOKEN` for the HotbarGames account). `R=HotbarGames/dialogue-ui-uall`.

Going public can't really be undone: anything visible for even a minute may already be cloned or archived. So
finish section 1 first.

## 1. Before: clean the history (done 2026-11-02)

The early history held internal notes, the owner's test plan, round-1 logo images made with Dialogue UI's icon as a
reference, and media whose quest text showed the owner's character name (now replaced with "Mavka"). A force-pushed
squash is not enough: GitHub keeps serving old commits by hash. So on 2026-11-02 the old repository was renamed to
`HotbarGames/dialogue-ui-uall-old` (private, kept as a backup) and this one was created fresh with a single commit
of the current files. Nothing of the old history is reachable from here.

- [ ] Delete `HotbarGames/dialogue-ui-uall-old` once nothing from it is needed (owner, on GitHub: Settings > Danger
      Zone > Delete this repository). Until then it stays private, which is enough.

Re-run these checks right before going public:

- [ ] Search the whole history:
      `git rev-list --all | xargs git grep -nIiE 'token|password|ghp_|github_pat_|foate|atei|/mnt/c|C:\Dev|129465795'`
      (expect no hits; `secret` appears only in Core.lua's comment about Midnight's secret strings).
- [ ] No character, realm or account names in docs or images (other players' names in screenshots are blurred).
- [ ] Every commit's author and committer is `HotbarGames <349335570+HotbarGames@users.noreply.github.com>`:
      `git log --all --format='%an <%ae> | %cn <%ce>' | sort -u`.
- [ ] `git ls-remote origin`: only `main` (no stray branches or tags).
- [ ] The addon passed the Forever test (`docs/TESTING.md`) and the CurseForge project exists.

## 2. Repository details (still private)

```bash
R=HotbarGames/dialogue-ui-uall
gh repo edit $R \
  --description "WoW Forever addon: shows Dialogue UI's quest and NPC window in Ukrainian with UALL Forever's translations. An unofficial bridge with no texts of its own: quest text through Dialogue UI's translator API, the rest of the window through UALL Forever's own hooks." \
  --homepage "https://www.curseforge.com/wow/addons/dialogue-ui-uall" \
  --add-topic world-of-warcraft,wow-addon,warcraft-addon,wow-forever,lua,ukrainian,localization,translation,dialogueui,curseforge
gh repo edit $R --enable-issues --enable-discussions --enable-wiki=false --enable-projects=false --delete-branch-on-merge
```

If the approved CurseForge project got a different slug, use that one.

## 3. Manual steps in Settings (no API for these)

- [ ] **Social preview**: Settings > General > Social preview > Edit > Upload an image. 1280x640 px PNG or JPG
      (at least 640x320, under 1 MB): `docs/media/social-preview.png`.
- [ ] **Sponsor button**: Settings > General > Features > tick **Sponsorships** (uses `.github/FUNDING.yml`).
- [ ] Discussions: keep the default categories or trim them to Q&A and Ideas.

## 4. Go public

```bash
gh repo edit $R --visibility public --accept-visibility-change-consequences
```

## 5. Right after (some of these are free only for public repositories)

```bash
# Private vulnerability reporting: SECURITY.md sends reporters to the Security tab, so this must be on.
gh api -X PUT repos/$R/private-vulnerability-reporting
# Secret scanning and push protection.
gh repo edit $R --enable-secret-scanning
gh repo edit $R --enable-secret-scanning-push-protection
# Dependabot alerts (covers the pinned GitHub Actions).
gh api -X PUT repos/$R/vulnerability-alerts
# Workflows get a read-only token unless they ask for more (release.yml asks for contents: write itself).
gh api -X PUT repos/$R/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
# Branch protection on main: no force pushes, no deletion. Direct pushes by the maintainer stay allowed.
gh api -X PUT repos/$R/branches/main/protection --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true
}
EOF
```

## 6. Release workflow (`.github/workflows/release.yml`)

- [ ] Add `## X-Curse-Project-ID: <id>` to `DialogueUI_UALL/DialogueUI_UALL.toc` (the numeric ID on the CurseForge
      project page). Without it, the packager skips the CurseForge upload.
- [ ] Create a CurseForge API token (CurseForge > My Profile > API Tokens) and store it as a repository secret.
      `gh secret set` asks for the value, so it never appears in the shell history or a chat:
      `gh secret set CF_API_TOKEN -R $R`
- [ ] Release: bump `## Version` and `CHANGELOG.md` together, commit, push, then
      `git tag v<version> && git push origin v<version>`. Watch the run: `gh run watch -R $R`.
      The packager uploads the zip to CurseForge and makes a GitHub release with the same zip.

## 7. Check as a stranger

- [ ] Open https://github.com/HotbarGames/dialogue-ui-uall in a private browser window (logged out): README and
      README.uk.md render, the logo shows, the Security tab shows the policy and "Report a vulnerability".
- [ ] New issue shows the bug report form and the two links (UALL team, private security report).
- [ ] `gh repo view $R --json visibility,description,homepageUrl,repositoryTopics,hasIssuesEnabled,hasDiscussionsEnabled`
- [ ] The one-click install link in both READMEs opens the CurseForge app.
