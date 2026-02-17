# Page Stickers - KOReader Plugin for Kobo

A [KOReader](https://github.com/koreader/koreader) plugin that lets you place stickers and images on book pages — like decorating a notebook with stickers while you read.

Built for the **Kobo Libra Color** (works on any KOReader-supported device).

## Features

- Place PNG/JPG/WebP sticker images anywhere on a book page
- **4 size presets**: Small, Medium, Large, Extra Large
- **4 rotation options**: 0°, 90°, 180°, 270°
- Choose size and rotation before placing — settings stick between placements
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

### Placing a sticker

1. Open a book in KOReader
2. Tap the top of the screen to open the menu
3. Go to **More tools > Page Stickers**
4. (Optional) Set your preferred **Sticker size** and **Sticker rotation**
5. Tap **Place sticker** — a picker shows your available stickers
6. Choose a sticker, then tap anywhere on the page to place it
7. Your stickers are saved automatically with the book

### How customization works

Size and rotation are set **before** you place a sticker, not after. This is by design — e-ink screens refresh slowly, so dragging/resizing after placement would be a poor experience. Instead:

1. Pick your size (Small → Extra Large)
2. Pick your rotation (0° → 270°)
3. Place as many stickers as you want with those settings
4. Change settings and place more with different sizes/rotations

Your size and rotation choices are remembered per book, so next time you open the same book they'll be the same as you left them.

### Size presets

| Preset | Screen % | Approx. pixels (Libra Color) |
|--------|----------|------------------------------|
| **Small** | 8% | ~100px |
| **Medium** | 12% | ~151px |
| **Large** | 18% | ~227px |
| **Extra Large** | 25% | ~316px |

Sizes scale proportionally on different screen sizes, so stickers look consistent across devices.

### Rotation options

| Option | Effect |
|--------|--------|
| **0°** | No rotation (default) |
| **90°** | Rotated clockwise |
| **180°** | Upside down |
| **270°** | Rotated counter-clockwise |

### Menu reference

Access via **More tools > Page Stickers**:

| Option | Description |
|--------|-------------|
| **Place sticker** | Pick a sticker from the gallery and tap the page to place it |
| **Sticker size** | Choose Small / Medium / Large / Extra Large |
| **Sticker rotation** | Choose 0° / 90° / 180° / 270° |
| **Show stickers** | Toggle sticker visibility on/off |
| **Undo last sticker on this page** | Remove the most recently placed sticker on the current page |
| **Clear stickers on this page** | Remove all stickers from the current page |
| **Clear all stickers in this book** | Remove every sticker in the current book (asks for confirmation) |

## Adding Your Own Stickers

### Where to put them

Drop image files into the `stickers/` folder inside the plugin directory:

```
sticker.koplugin/
  stickers/
    heart.png      <-- your stickers go here
    star.png
    cat.jpg
    ...
```

On the Kobo device, the full path is:
```
/mnt/onboard/.adds/koreader/plugins/sticker.koplugin/stickers/
```

### Supported formats

| Format | Transparency | Recommended |
|--------|-------------|-------------|
| **PNG** | Yes (alpha channel) | Best choice |
| **JPG/JPEG** | No | OK for opaque stickers |
| **WebP** | Yes | Works, but PNG is safer |

### Recommended sticker specs

| Property | Recommendation |
|----------|---------------|
| **Format** | PNG with transparent background |
| **Source size** | 512x512 pixels |
| **Aspect ratio** | Square (1:1) — the plugin renders stickers as squares |
| **Color** | Color works on Kobo Libra Color; will render as grayscale on B&W devices |
| **File name** | Short, descriptive (shown in the picker menu). Use `heart.png` not `IMG_20240301_sticker_v2_final.png` |
| **File size** | Keep under 500KB per sticker for fast loading |
| **Background** | Transparent (PNG alpha) for best results. Opaque backgrounds will cover book text. |

### Tips for creating stickers

- **Transparent PNGs are key** — the plugin uses alpha blending, so stickers with transparent backgrounds look like they're placed on the page naturally
- **512x512 is the sweet spot** — high enough quality at any size preset, but not so large that it wastes memory on the e-reader
- **Square images work best** — the plugin renders stickers as squares. Non-square images will be stretched to fit
- **Solid outlines help** — on an e-ink display, stickers with clean outlines are more readable than ones with soft/blurred edges
- **Test with both color and B&W** — Kobo Libra Color has a color screen, but the color resolution (150 PPI) is lower than B&W (300 PPI). Bold, simple designs look best

### Where to find stickers

- Create your own in any image editor (Photoshop, GIMP, Canva, etc.)
- Export PNG with transparency enabled
- Free sticker packs from sites like OpenClipart, Flaticon, or Freepik (check licenses)

## How It Works

The plugin uses KOReader's `registerViewModule` API to hook into the page rendering pipeline. On every page paint, it checks if the current page has any stickers and alpha-blits them onto the screen buffer. Sticker placement data (coordinates, size, rotation, image path) is saved in the book's sidecar metadata file (`<bookname>.sdr/metadata.*.lua`), so stickers persist across sessions and are tied to the specific book.

### Architecture

```
main.lua          Thin KOReader integration layer (menus, events, painting)
    |
    v
stickerstore.lua  Pure data logic (zero KOReader dependencies, fully testable)
```

## Development

### Project structure

```
sticker.koplugin/
  _meta.lua           # Plugin metadata (name, description)
  main.lua            # KOReader integration (menus, touch, rendering)
  stickerstore.lua    # Pure data layer (add/remove/serialize stickers)
  stickers/           # Drop your sticker images here

spec/
  tinytest.lua        # Minimal pure-Lua test runner
  stickerstore_spec.lua  # 30 data layer tests
  main_spec.lua          # 43 integration tests with mocked KOReader APIs
  mocks/
    koreader_mocks.lua   # Mocks for Screen, UIManager, RenderImage, etc.

run_tests.sh          # Run all tests
```

### Running tests

Requires Lua 5.4 (no other dependencies):

```bash
bash run_tests.sh
```

Or run individually:

```bash
lua spec/stickerstore_spec.lua   # Data layer tests only
lua spec/main_spec.lua           # Integration tests only
```

### Testing without a device

The codebase is designed for blind development:

- **`stickerstore.lua`** has zero KOReader dependencies — pure Lua, testable anywhere
- **`main.lua`** is tested via mocks that simulate KOReader's Screen, UIManager, RenderImage, BlitBuffer, and widget infrastructure
- 73 tests cover: placement, undo, serialization, rotation, size presets, caching, painting, menu callbacks, settings persistence, and edge cases

## License

MIT

## Credits

Made with love as a gift.
