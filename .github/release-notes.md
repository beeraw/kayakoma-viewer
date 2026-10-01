## Requirements

macOS 14 or later.

## Install

1. Download `{{ASSET}}` below and unzip it.
2. Move **Kayakoma Viewer** to your Applications folder.

## First open

The app is not signed with an Apple Developer ID and is not notarized by Apple, so macOS blocks it the first time you open it. To allow it once:

- Open **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to the message about Kayakoma Viewer, then confirm; or
- right-click the app in the Finder, choose **Open**, then confirm.

Alternatively, remove the quarantine flag in Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/Kayakoma Viewer.app"
```

## Quick Look

Launch Kayakoma Viewer once from the Applications folder so that macOS registers its Quick Look extension. Then select a Markdown file in the Finder and press the space bar.

## Checksum

SHA-256 of `{{ASSET}}`:

```
{{SHA256}}
```
