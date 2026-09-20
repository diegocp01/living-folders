# Living Folders

**Name a folder in plain language. The files walk in by themselves.**

A native macOS app. Open any folder, start typing what you want — `screenshots from last week`, `tax stuff`, `python tutorials` — and the matching files gather as you type. When it looks right, approve. The folder becomes real.

![Living Folders in use](docs/screenshot.png)

SwiftUI. No web view, no server, no account, no network unless you ask for it.

---

## Ask your AI agent to install it

If you already have a coding agent on your Mac — **Codex**, **Claude Code**, **Muse**, **Grok bot**, or anything else that can run shell commands — copy the block below and paste it into your agent. It has everything the agent needs.

````markdown
Please install Living Folders on my Mac.

Repo: https://github.com/diegocp01/living-folders.git

Steps:

```bash
git clone https://github.com/diegocp01/living-folders.git
cd living-folders
./build.sh --open
```

That produces `build/LivingFolders.app` and launches it.

Before you start, check the requirements and tell me if either is missing
instead of installing anything yourself:
- macOS 14 or later  (`sw_vers -productVersion`)
- Xcode 15 or later, Swift 5.9  (`xcodebuild -version`)

Notes:
- This only builds and opens an app. Do not move, rename or delete any of my
  files as part of the install.
- The app itself never touches files without showing me the exact commands
  and waiting for my approval.
````

Prefer to do it yourself? See [Install manually](#install-manually).

---

## What makes it safe

This app moves real files, so the whole design is built around you seeing it coming.

- **Nothing happens until you approve.** Typing only previews. An approve sheet shows the exact items and the exact shell commands before anything runs.
- **Nothing is ever overwritten.** The move uses `mv -n`, which refuses to clobber an existing file.
- **Nothing is ever deleted.** There is no delete path in the app at all.
- **No surprise destinations.** The name you type is sanitised into a single path component — `/`, `:` and leading dots are stripped — and the app will not move a folder into itself.
- **No network by default.** Classification runs on your Mac. The optional cloud path is off unless you set a key.

The commands you approve are always just these two:

```
/bin/mkdir -p '<folder you opened>/<name you typed>'
/bin/mv -n '<item 1>' '<item 2>' … '<folder you opened>/<name you typed>'
```

---

## How it works

1. **Open a folder.** Use *Open Folder…*, drag one onto the window, or pick a recent one. The app lists the visible top-level files and folders.
2. **Type a name.** Every keystroke reclassifies. A space or a paste dispatches instantly; an unfinished word waits 90 ms. Cards fly between the desktop and the folder pane in a 300 ms spring.
3. **Approve.** Press ⌘↩ or click *Move N*, read the sheet, confirm.

### How it decides what belongs

**On-device rules (the default).** No network. Each item is scored on four signals:

| You type | It matches on |
|---|---|
| `photos`, `screenshots`, `PDFs`, `installers`, `code`, `music` | file type, by extension |
| `trip`, `taxes`, or any topic | filename, with synonyms (`trip` → flight, hotel, itinerary, passport; `taxes` → irs, w2, 1099) |
| `today`, `this week`, `last month`, `old` | modification date |
| `folders`, `files` | directories or regular files |

**Jev (optional).** Set `TYPESAFE_API_KEY` in your environment or in the app's Settings. Each folder name is then sent to Jev (`jev-latest`, one `noul` question per item) along with the names, kinds and dates of the files in the open folder.

> This path is implemented but has **not** been exercised against the live API. Treat it as untested.

---

## Install manually

Requires macOS 14+ and Xcode 15+ (Swift 5.9).

```bash
git clone https://github.com/diegocp01/living-folders.git
cd living-folders
./build.sh --open
```

To develop in Xcode, run `open Package.swift` and use the `LivingFolders` scheme.

To launch straight into a folder:

```bash
open build/LivingFolders.app --args ~/Downloads
```

---

## Test

```bash
swift test
```

The suite covers the classifier rules, folder-name sanitising, shell quoting, and a real `mkdir` + `mv` run inside a temporary directory.

---

## Project layout

| Path | What's in it |
|---|---|
| `Sources/LivingFoldersCore/` | `FolderScanner`, `LocalClassifier`, `JevClassifier`, `ShellMover` — no UI, fully testable |
| `Sources/LivingFolders/` | SwiftUI app: welcome screen, card field, prompt bar, approve sheet |
| `Tests/LivingFoldersCoreTests/` | Offline tests |
| `build.sh` | Assembles `build/LivingFolders.app` |
