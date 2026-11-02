# Releasing a new version

A version tag (`v1.0.1`, ...) runs `.github/workflows/release.yml`: it builds the zip, uploads it to CurseForge
(project 1779758, game type Forever, game versions from the TOC's `## Interface`) and makes a GitHub release with
the same zip. The tag name becomes the version label on CurseForge.

## Steps

1. If Blizzard changed Forever's interface number (in game: `/dump select(4, GetBuildInfo())`), test the addon on
   the new client and add the number in front: `## Interface: 16002, 16001`. Without it, players see the addon as
   "out of date".
2. Bump `## Version` in `DialogueUI_UALL/DialogueUI_UALL.toc` and add a section on top of
   `DialogueUI_UALL/CHANGELOG.md` (English, then a «Українською:» line). The changelog is uploaded as written.
3. Commit and push to `main`.
4. Optional dry run (uploads nothing): Actions > release > Run workflow, or `gh workflow run release.yml`. Its log
   shows whether CurseForge accepts the token and lists each TOC interface for Forever, e.g.
   `TOC interface 16002 -> 1.60.2: listed`. "Not listed yet" means CurseForge hasn't added that game version: the
   upload would then use the nearest lower one; wait a day or upload anyway.
5. Tag and push: `git tag v1.0.1 && git push origin v1.0.1`, then `gh run watch` (or the Actions tab).
   A tag containing `alpha` or `beta` uploads as that release type.

Checked on 2026-11-02 with the dry run: token accepted, `16001 -> 1.60.1` listed (CurseForge has no 1.60.0, which
is harmless), zip identical to the hand-built 1.0.0 one.
