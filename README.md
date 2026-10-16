# Murinook

A native macOS clipboard manager and temporary drag-and-drop shelf. Keep recent copies within reach, organize what matters, and carry files between apps from a small panel at the edge of your screen.

**macOS 15+ · Apple silicon & Intel · English & Ukrainian**

## Download

[Download Murinook 0.1.0-beta.3 (universal DMG)](https://github.com/Wonsky1/murinook/releases/download/v0.1.0-beta.3/Murinook-0.1.0-beta.3-universal.dmg) · [Release notes](https://github.com/Wonsky1/murinook/releases/tag/v0.1.0-beta.3)

1. Open the DMG and drag **Murinook** into **Applications**.
2. Launch Murinook from Applications. Its icon appears in the menu bar; showing it in the Dock is optional.
3. If direct paste asks for access, grant Murinook **Accessibility** permission in System Settings. Clipboard copying remains available without that permission.

This beta is ad-hoc signed and **not notarized**. If macOS blocks it, first try opening the app, then go to **System Settings → Privacy & Security → Open Anyway**. See [Apple's instructions](https://support.apple.com/en-us/102445).

## What it does

- **Clipboard history:** capture and search recent clips, organize them into collections, pin items, add notes and tags, preview content, and export selections.
- **Quick Access:** find and paste a recent clip from a compact keyboard-driven panel.
- **Three history layouts:** switch between tiles, a chronological list, and a horizontal strip.
- **Temporary shelf:** drag supported content to reveal the shelf. Dropped items remain available while you work; move the shelf along a screen edge, hide it to a small restore button, and drag items out when ready.
- **Paste queue:** line up clips and paste them one at a time.
- **Configurable shortcuts:** record your own key combinations or disable individual global shortcuts.
- **English and Ukrainian:** choose either language in Settings, or follow the system language.

## Keyboard shortcuts

| Action | Default |
| --- | --- |
| Quick Access | `⇧⌘V` |
| Library | `⌃⌥B` |
| Shelf | `⌃⌥S` |
| Paste next queued item | `⌃⌥V` |

Change these in **Settings → Shortcuts**. In Quick Access, click a clip or press Return to paste it, Shift-Return to paste plain text, and Escape to dismiss the panel.

## Updates

Murinook checks GitHub Releases at launch when automatic checks are enabled. It offers **stable releases only**; beta releases are skipped. You can also choose **Check for updates** from the menu bar or **Settings → Updates**.

When a newer stable version is available, the menu bar icon gains a small indicator and the Updates page offers **Download DMG** and **Release notes**. Installation is manual:

1. Download and open the new DMG.
2. Quit Murinook.
3. Replace Murinook in Applications and launch it again.

Development builds and this ad-hoc signed beta use different signing identities. macOS may ask you to authorize access to existing app data or grant Accessibility access again. Keep a backup when moving between development and release builds.

Automatic checks can be disabled in Settings. The currently published `0.1.0-beta.3` is a prerelease, so it is available through the download link above rather than the stable update feed.

## Privacy and your data

- History, collections, shelf items, and preferences are stored locally in your user Library, separately from the app. Replacing the app during an update does not delete this storage. The paste queue is kept only for the current session.
- History retention and item limits are configurable. Pinned clips are exempt from automatic history cleanup.
- Files and folders added to the shelf are normally **references to their originals**, not duplicate copies. Keep the originals available. Temporary exports and promised files supplied by other apps may need a local copy.
- Dragging a shelf file out copies it to the destination. Accepted transfers remove it from the shelf when automatic removal is enabled; removing it from the shelf never deletes its original.
- Capture can be paused and apps can be excluded. Clipboard representations marked private, concealed, or transient are skipped, but these conventions depend on the source app. Clipboard history may contain sensitive information.
- Optional update checks request public release metadata from GitHub. Clipboard contents are not sent in those requests. There is no cloud sync or image OCR in this release.

Deleting only the `.app` leaves its separate data storage in place. Cleanup tools that also remove application data can erase history and settings. Back up important data before a complete uninstall.

## Build from source

Clone this repository, open `Murinook.xcodeproj` in Xcode, select the **Murinook** scheme and **My Mac**, then Run. The app uses the local `Packages/MurinookKit` Swift package; the reference apps used during development are not required.

Run the package tests:

```sh
swift test --package-path Packages/MurinookKit
```

To create a universal Release DMG locally:

```sh
./scripts/package-dmg.sh
```

The output is written to `work/releases/` with a SHA-256 checksum. The packaging script uses ad-hoc signing; Developer ID signing and notarization require a separate distribution setup.
