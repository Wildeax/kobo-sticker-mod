# Page Stickers - KOReader Plugin for Kobo

A [KOReader](https://github.com/koreader/koreader) plugin that lets you place stickers and images on book pages — like decorating a notebook with stickers while you read.

Built for the **Kobo Libra Color** (works on any KOReader-supported device).

## Features

- Place PNG/JPG/WebP sticker images anywhere on a book page
- Stickers are saved per-book and persist between sessions
- Pick from a sticker gallery before placing
- Toggle sticker visibility on/off
- Undo last sticker or clear all stickers on a page
- Works with transparent PNGs (alpha blending)

## Prerequisites

Your Kobo needs **KOReader** installed. If you don't have it yet:

1. Download the latest KOReader release for Kobo from [koreader.rocks](https://koreader.rocks/) or [GitHub releases](https://github.com/koreader/koreader/releases)
2. Connect your Kobo to your computer via USB
3. Extract the `koreader` folder to `/mnt/onboard/.adds/` on your Kobo (the `.adds` folder may be hidden — on Windows enable "Show hidden files", on macOS press `Cmd+Shift+.`)
4. Install **NickelMenu** from [GitHub](https://github.com/pgaskin/NickelMenu/releases) to add a menu entry to launch KOReader:
   - Download `KoboRoot.tgz`
   - Place it in the `.kobo/` folder on your Kobo
   - Eject and reboot
5. Create the file `.adds/nm/koreader` with this content:
   ```
   menu_item:main:KOReader:cmd_spawn:quiet:exec /mnt/onboard/.adds/koreader/koreader.sh
   ```
6. KOReader will now appear in your Kobo's main menu

## Installation

1. Connect your Kobo to your computer via USB
2. Copy the `sticker.koplugin` folder to:
   ```
   /mnt/onboard/.adds/koreader/plugins/sticker.koplugin/
   ```
3. Add your sticker images (PNG, JPG, or WebP) to:
   ```
   /mnt/onboard/.adds/koreader/plugins/sticker.koplugin/stickers/
   ```
4. Eject your Kobo and restart KOReader

## Usage

1. Open a book in KOReader
2. Tap the top of the screen to open the menu
3. Go to **More tools > Page Stickers**
4. Tap **Place sticker** — a picker shows your available stickers
5. Choose a sticker, then tap anywhere on the page to place it
6. Your stickers are saved automatically with the book

### Menu Options

| Option | Description |
|--------|-------------|
| **Place sticker** | Pick a sticker and tap to place it on the current page |
| **Show stickers** | Toggle sticker visibility on/off |
| **Undo last sticker on this page** | Remove the most recently placed sticker on the current page |
| **Clear stickers on this page** | Remove all stickers from the current page |
| **Clear all stickers in this book** | Remove every sticker in the current book (asks for confirmation) |

## Adding Your Own Stickers

Drop any PNG, JPG, or WebP image into the `stickers/` folder inside the plugin directory. Transparent PNGs work best — the transparency is preserved when rendered on the page.

**Recommended sticker specs:**
- Format: PNG with transparency
- Size: 200x200 to 500x500 pixels (they get scaled to ~12% of screen width)
- Keep file names short and descriptive (the file name is shown in the picker)

## How It Works

The plugin uses KOReader's `registerViewModule` API to hook into the page rendering pipeline. On every page paint, it checks if the current page has any stickers and alpha-blits them onto the screen buffer. Sticker placement data (coordinates, size, image path) is saved in the book's sidecar metadata file, so stickers persist across sessions and are tied to the specific book.

## Project Structure

```
sticker.koplugin/
  _meta.lua          # Plugin metadata (name, description)
  main.lua           # Plugin logic
  stickers/          # Drop your sticker images here
    heart.png
    star.png
    ...
```

## License

MIT

## Credits

Made with love as a gift.
