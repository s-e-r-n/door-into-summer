# SSOP: the app installed in /Applications, signed with the keychain's identity

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The fonts' resource bundle | SwiftPM's build, copied by make_app.sh into `Contents/Resources` | `registeredFonts()` | `Bundle.main.url(forResource:withExtension:)` | `Bundle?`, found in `Contents/Resources` of the app or beside the bare binary | a path compiled into the binary that names the worktree that built it |
| The signing identity | the keychain | `codesign` in install_app.sh | `security find-identity -v -p codesigning`, the lines naming `Apple Development:` | one SHA-1 hash, exactly one match or exit 1 | an identity name, email or team ID written in the public repository, a choice among several identities |
| The built app | make_app.sh, its standard output | install_app.sh | the path make_app.sh prints | the absolute path of `app/.build/Door into Summer.app`, signed ad hoc | a development bundle signed with the identity |
| The installed app | install_app.sh | Raycast, Spotlight, Finder | the signed copy moved into `/Applications` | `/Applications/Door into Summer.app`, signed with the identity | a half signed app in `/Applications` when signing fails |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `registeredFonts()` reading `Bundle.main` | the resource bundle beside the executable or in `Contents/Resources` | nothing | the fonts registered for the process | main.swift |
| install_app.sh | make_app.sh, the signing identity | nothing | the installed path on standard output | app/scripts/install_app.sh |

Edges: make_app.sh → install_app.sh; the binary make_app.sh bundles carries `registeredFonts()`.

Batches: 1. `registeredFonts()`. 2. install_app.sh.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| `registeredFonts()` | where the fonts' resource bundle is found | nothing new |
| install_app.sh | where the app is installed and which identity signs it | run it from any checkout; it needs exactly one valid Apple Development identity in the keychain, writes `/Applications/Door into Summer.app` and prints its path |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The signing identity | the keychain | install_app.sh | the human, outside the repository |
| The development bundle and its ad hoc signature | make_app.sh | install_app.sh, every worktree run | make_app.sh |
| The installed app | install_app.sh | Raycast, Spotlight, Finder | install_app.sh |
