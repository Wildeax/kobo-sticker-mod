#!/bin/bash
# Run all tests for the Page Stickers KOReader plugin.
# Requires Lua 5.4 (or 5.3/5.1).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

LUA="${LUA:-lua}"

# Try to find lua if not in PATH
if ! command -v "$LUA" &>/dev/null; then
    for candidate in \
        "/c/Users/$USER/AppData/Local/Programs/Lua/bin/lua.exe" \
        "/usr/local/bin/lua" \
        "/usr/bin/lua" \
        "/usr/bin/lua5.4" \
        "/usr/bin/lua5.3"; do
        if [ -x "$candidate" ]; then
            LUA="$candidate"
            break
        fi
    done
fi

if ! command -v "$LUA" &>/dev/null && [ ! -x "$LUA" ]; then
    echo "ERROR: lua not found. Install Lua or set LUA=/path/to/lua"
    exit 1
fi

echo "Using: $($LUA -v 2>&1)"
echo ""

EXIT=0

echo "=== StickerStore tests ==="
"$LUA" spec/stickerstore_spec.lua || EXIT=1
echo ""

echo "=== PageSticker (main.lua) tests ==="
"$LUA" spec/main_spec.lua || EXIT=1

exit $EXIT
