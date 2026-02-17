--- StickerStore: pure data layer for page stickers.
-- Zero KOReader dependencies — testable with plain Lua.

local StickerStore = {}
StickerStore.__index = StickerStore

-- Size presets as fraction of screen width.
StickerStore.SIZE_PRESETS = {
    small  = 0.08,  -- ~100px on Libra Color
    medium = 0.12,  -- ~151px (default)
    large  = 0.18,  -- ~227px
    xlarge = 0.25,  -- ~316px
}

-- Valid rotation angles.
StickerStore.VALID_ROTATIONS = { [0] = true, [90] = true, [180] = true, [270] = true }

function StickerStore:new()
    local o = setmetatable({}, self)
    o.pages = {}  -- { [page_number] = { {x, y, w, h, img, rotation}, ... } }
    return o
end

--- Add a sticker to a page.
-- @param page number Page number
-- @param x number X coordinate (top-left of sticker)
-- @param y number Y coordinate (top-left of sticker)
-- @param w number Width in pixels
-- @param h number Height in pixels
-- @param img string Path to sticker image file
-- @param rotation number Rotation in degrees (0, 90, 180, 270). Default 0.
function StickerStore:addSticker(page, x, y, w, h, img, rotation)
    if not page or not x or not y or not w or not h or not img then
        return false, "missing required fields"
    end
    if type(page) ~= "number" or page < 1 then
        return false, "invalid page number"
    end
    rotation = rotation or 0
    if not self.VALID_ROTATIONS[rotation] then
        return false, "invalid rotation (must be 0, 90, 180, or 270)"
    end
    if not self.pages[page] then
        self.pages[page] = {}
    end
    table.insert(self.pages[page], {
        x = x,
        y = y,
        w = w,
        h = h,
        img = img,
        rotation = rotation,
    })
    return true
end

--- Compute sticker pixel size from a preset name and screen width.
-- @param preset string Preset name ("small", "medium", "large", "xlarge")
-- @param screen_width number Screen width in pixels
-- @return number Size in pixels, or nil if preset is invalid
function StickerStore.sizeFromPreset(preset, screen_width)
    local ratio = StickerStore.SIZE_PRESETS[preset]
    if not ratio then return nil end
    return math.floor(screen_width * ratio)
end

--- Remove the last sticker placed on a page (undo).
-- @param page number Page number
-- @return table|nil The removed sticker, or nil if page was empty
function StickerStore:removeLastSticker(page)
    if not self.pages[page] or #self.pages[page] == 0 then
        return nil
    end
    local removed = table.remove(self.pages[page])
    if #self.pages[page] == 0 then
        self.pages[page] = nil
    end
    return removed
end

--- Clear all stickers on a specific page.
-- @param page number Page number
-- @return number Count of stickers removed
function StickerStore:clearPage(page)
    local stickers = self.pages[page]
    local count = stickers and #stickers or 0
    self.pages[page] = nil
    return count
end

--- Clear all stickers from all pages.
-- @return number Total count of stickers removed
function StickerStore:clearAll()
    local count = 0
    for _, stickers in pairs(self.pages) do
        count = count + #stickers
    end
    self.pages = {}
    return count
end

--- Get all stickers on a given page.
-- @param page number Page number
-- @return table List of sticker records (may be empty)
function StickerStore:getStickersForPage(page)
    return self.pages[page] or {}
end

--- Get count of stickers on a page.
-- @param page number Page number
-- @return number
function StickerStore:getCountForPage(page)
    return self.pages[page] and #self.pages[page] or 0
end

--- Get total count of stickers across all pages.
-- @return number
function StickerStore:getTotalCount()
    local count = 0
    for _, stickers in pairs(self.pages) do
        count = count + #stickers
    end
    return count
end

--- Get list of page numbers that have stickers, sorted.
-- @return table Sorted list of page numbers
function StickerStore:getPagesWithStickers()
    local result = {}
    for page, _ in pairs(self.pages) do
        table.insert(result, page)
    end
    table.sort(result)
    return result
end

--- Serialize sticker data for persistence.
-- Returns the raw pages table (KOReader's doc_settings handles serialization).
-- @return table
function StickerStore:serialize()
    return self.pages
end

--- Deserialize sticker data from saved state.
-- @param data table Previously serialized pages table
function StickerStore:deserialize(data)
    if type(data) == "table" then
        self.pages = data
    else
        self.pages = {}
    end
end

--- Scan a directory for sticker image files.
-- @param dir_path string Path to scan
-- @param lfs_module table Optional lfs module (for dependency injection in tests)
-- @return table List of { path = string, name = string }
function StickerStore.scanDirectory(dir_path, lfs_module)
    local lfs = lfs_module
    if not lfs then
        local ok
        ok, lfs = pcall(require, "lfs")
        if not ok then
            -- Fallback: try KOReader's bundled lfs
            ok, lfs = pcall(require, "libs/libkoreader-lfs")
            if not ok then
                return {}, "lfs not available"
            end
        end
    end

    local stickers = {}
    local ok, iter, dir_obj = pcall(lfs.dir, dir_path)
    if not ok then
        return {}, "cannot read directory: " .. tostring(dir_path)
    end

    for entry in iter, dir_obj do
        if entry ~= "." and entry ~= ".." then
            local ext = entry:lower():match("%.(%w+)$")
            if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp" then
                table.insert(stickers, {
                    path = dir_path .. "/" .. entry,
                    name = entry:match("^(.+)%..+$") or entry,
                })
            end
        end
    end

    table.sort(stickers, function(a, b) return a.name < b.name end)
    return stickers
end

return StickerStore
