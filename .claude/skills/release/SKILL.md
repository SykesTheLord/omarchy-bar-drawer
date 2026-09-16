---
name: release
description: Publish a new version of the bar drawer to GitHub so users can install or update it with omarchy plugin add/update.
disable-model-invocation: true
---

Release a new version. Arguments: $ARGUMENTS (an explicit version like `1.2.0`, or `patch`, `minor`, or `major`; default `patch`).

`omarchy plugin update` fast-forward pulls the default branch, so a release reaches users when that branch is pushed. Tags are for humans.

1. Preconditions:
   - Not a git repo yet: stop and offer `git init`. Don't run it without a yes.
   - No GitHub remote: offer `gh repo create sykesthelord/omarchy-bar-drawer --public --source . --remote origin`. Confirm first; it publishes the code.
   - The working tree must be clean apart from the release changes. `CLAUDE.local.md` must not be tracked.
2. Compute the new version from `manifest.json`'s `version`, then update it with `jq` (write to a temp file, then move it into place).
3. Run `omarchy plugin validate .`. Stop if it fails.
4. Show the user the version change and the commits since the last tag (`git log --oneline <last-tag>..HEAD`, or all commits if there are no tags). Wait for confirmation.
5. Commit `manifest.json` with the message `Release v<version>`, including the session's attribution lines. Tag it `v<version>`.
6. Push the branch and the tag: `git push origin HEAD --follow-tags`.
7. Report the new version, the tag, and the install command: `omarchy plugin add https://github.com/sykesthelord/omarchy-bar-drawer.git`.
