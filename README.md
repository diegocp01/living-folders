# Living Folders

**What if naming a folder was all you had to do to organize it?**

A native macOS app. Open a folder, type what you want in plain language, and watch the matching files gather into a new folder as you type. When it looks right, approve — the app runs `/bin/mkdir` and `/bin/mv` and the folder becomes real.

Built with SwiftUI. No web view, no server, no account.

## Run

Requires macOS 14+ and Xcode 15+ (Swift 5.9).

```bash
git clone https://github.com/diegocp01/living-folders
cd living-folders
./build.sh --open
```

This produces `build/LivingFolders.app` and launches it. To develop in Xcode, `open Package.swift` and run the `LivingFolders` scheme. You can also open a folder directly:

```bash
open build/LivingFolders.app --args ~/Downloads
```

## How it works

1. **Open a folder** (Open Folder…, drag one onto the window, or pick a recent one). The app lists its visible top-level files and folders.
2. **Name the folder.** Every keystroke reclassifies; a space or paste dispatches instantly, unfinished words wait 90 ms. Cards fly between the desktop and the folder pane in a 300 ms spring.
3. **Approve.** Press ⌘↩ or click *Move N*. A sheet shows exactly which items will move and the exact shell commands. Nothing runs until you confirm.

The move is:

```
/bin/mkdir -p '<folder you opened>/<name you typed>'
/bin/mv -n '<item 1>' '<item 2>' … '<folder you opened>/<name you typed>'
```

`mv -n` never overwrites. Nothing is ever deleted. The name you typed is sanitised into a single path component (`/`, `:` and leading dots are stripped), and the app never moves the destination into itself.

## Classification

**On-device rules (default).** No network. Scores each item from three signals:

- file-type words → extensions (`photos`, `screenshots`, `PDFs`, `installers`, `code`, `music`, …)
- topic words → filename matches, with synonyms (`trip` → flight, hotel, itinerary, passport…; `taxes` → irs, w2, 1099…)
- time words → modification date (`today`, `this week`, `last month`, `old`)
- `folders` / `files` to prefer directories or regular files

**Jev (optional).** Set `TYPESAFE_API_KEY` in the environment or in the app's Settings. Each folder name is then sent to Jev (`jev-latest`, one `noul` question per item) with the names, kinds, and dates of the files in the open folder. This path is implemented but was not exercised against the live API.

## Test

```bash
swift test
```

The tests cover the classifier rules, folder-name sanitising, shell quoting, and a real `mkdir` + `mv` run inside a temporary directory.

## Project files

- `Sources/LivingFoldersCore/` — `FolderScanner`, `LocalClassifier`, `JevClassifier`, `ShellMover` (no UI, fully testable)
- `Sources/LivingFolders/` — SwiftUI app: welcome screen, card field, prompt bar, approve sheet
- `Tests/LivingFoldersCoreTests/` — offline tests
- `build.sh` — assembles `build/LivingFolders.app`
