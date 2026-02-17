local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local RenderImage = require("ui/renderimage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = require("device").screen
local logger = require("logger")
local _ = require("gettext")

local StickerStore = require("stickerstore")

local PageSticker = WidgetContainer:extend{
    name = "sticker",
    is_doc_only = true,
    store = nil,            -- StickerStore instance
    sticker_cache = nil,    -- cached BlitBuffers keyed by path|w|h|rotation
    current_page = nil,
    is_placing = false,
    is_visible = true,
    selected_sticker = nil, -- path to the sticker image to place
    -- Pre-placement settings (persist across placements within a session)
    current_size_preset = "medium",
    current_rotation = 0,
}

function PageSticker:onDispatcherRegisterActions()
    Dispatcher:registerAction("sticker_place", {
        category = "none",
        event = "StickerStartPlacement",
        title = _("Place a sticker"),
        reader = true,
    })
    Dispatcher:registerAction("sticker_toggle", {
        category = "none",
        event = "StickerToggleVisibility",
        title = _("Toggle sticker visibility"),
        reader = true,
    })
end

function PageSticker:init()
    logger.dbg("Sticker: init() called")
    self.store = StickerStore:new()
    self.sticker_cache = {}
    self.current_size_preset = "medium"
    self.current_rotation = 0
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    logger.dbg("Sticker: init() complete, screen width:", Screen:getWidth())
end

function PageSticker:onReaderReady()
    logger.dbg("Sticker: onReaderReady(), registering view module")
    self.view:registerViewModule("sticker", self)
end

function PageSticker:onReadSettings(config)
    logger.dbg("Sticker: onReadSettings()")
    local data = config:readSetting("sticker_data")
    self.store:deserialize(data)
    self.is_visible = config:readSetting("sticker_visible")
    if self.is_visible == nil then
        self.is_visible = true
    end
    self.current_size_preset = config:readSetting("sticker_size_preset") or "medium"
    self.current_rotation = config:readSetting("sticker_rotation") or 0
    logger.dbg("Sticker: loaded", self.store:getTotalCount(), "stickers,",
               "visible:", self.is_visible,
               "size:", self.current_size_preset,
               "rotation:", self.current_rotation)
end

function PageSticker:onSaveSettings()
    logger.dbg("Sticker: onSaveSettings(),", self.store:getTotalCount(), "stickers")
    self.ui.doc_settings:saveSetting("sticker_data", self.store:serialize())
    self.ui.doc_settings:saveSetting("sticker_visible", self.is_visible)
    self.ui.doc_settings:saveSetting("sticker_size_preset", self.current_size_preset)
    self.ui.doc_settings:saveSetting("sticker_rotation", self.current_rotation)
end

function PageSticker:onPageUpdate(pageno)
    self.current_page = pageno
end

--- Get the current sticker size in pixels.
function PageSticker:getCurrentStickerSize()
    return StickerStore.sizeFromPreset(self.current_size_preset, Screen:getWidth())
        or StickerStore.sizeFromPreset("medium", Screen:getWidth())
end

--- Load and cache a sticker image as a BlitBuffer.
function PageSticker:getStickerBB(img_path, w, h, rotation)
    rotation = rotation or 0
    local key = img_path .. "|" .. tostring(w) .. "|" .. tostring(h) .. "|" .. tostring(rotation)
    if not self.sticker_cache[key] then
        logger.dbg("Sticker: loading image:", img_path, "size:", w, "x", h, "rotation:", rotation)
        local bb = RenderImage:renderImageFile(img_path, false, w, h)
        if bb then
            if rotation ~= 0 and bb.rotatedCopy then
                local rotated = bb:rotatedCopy(rotation)
                bb:free()
                bb = rotated
            end
            self.sticker_cache[key] = bb
            logger.dbg("Sticker: image loaded and cached:", img_path)
        else
            logger.warn("Sticker: FAILED to load image:", img_path)
        end
    end
    return self.sticker_cache[key]
end

--- Paint all stickers for the current page onto the screen buffer.
function PageSticker:paintTo(bb, x, y)
    if not self.is_visible or not self.current_page then return end
    local page_stickers = self.store:getStickersForPage(self.current_page)
    if #page_stickers == 0 then return end

    for _, s in ipairs(page_stickers) do
        local sticker_bb = self:getStickerBB(s.img, s.w, s.h, s.rotation)
        if sticker_bb then
            local dest_x = x + s.x
            local dest_y = y + s.y
            bb:alphablitFrom(sticker_bb, dest_x, dest_y, 0, 0, s.w, s.h)
        end
    end
end

--- Show a menu to pick which sticker to place, then enter placement mode.
function PageSticker:onStickerStartPlacement()
    logger.dbg("Sticker: scanning stickers directory:", self.path .. "/stickers")
    local available = StickerStore.scanDirectory(self.path .. "/stickers")
    logger.dbg("Sticker: found", #available, "sticker images")
    if #available == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No stickers found.\n\nAdd PNG or JPG images to:\nsticker.koplugin/stickers/"),
        })
        return true
    end

    local buttons = {}
    for _, s in ipairs(available) do
        logger.dbg("Sticker: available:", s.name, "->", s.path)
        table.insert(buttons, {{
            text = s.name,
            callback = function()
                self.selected_sticker = s.path
                logger.dbg("Sticker: selected:", s.name)
                self:enterPlacementMode()
                UIManager:close(self._picker)
            end,
        }})
    end

    local ButtonDialogTitle = require("ui/widget/buttondialogtitle")
    self._picker = ButtonDialogTitle:new{
        title = _("Choose a sticker"),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(self._picker)
    return true
end

--- Enter placement mode: the next tap on the page places the selected sticker.
function PageSticker:enterPlacementMode()
    self.is_placing = true
    local size_label = self.current_size_preset
    local rot_label = self.current_rotation .. "°"
    logger.dbg("Sticker: entering placement mode, size:", size_label, "rotation:", rot_label)
    UIManager:show(InfoMessage:new{
        text = _("Tap to place sticker.") .. "\n" ..
               _("Size: ") .. size_label .. " | " .. _("Rotation: ") .. rot_label,
        timeout = 2,
    })
    self.ui:registerTouchZones({
        {
            id = "sticker_place_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = 0, ratio_y = 0,
                ratio_w = 1, ratio_h = 1,
            },
            overrides = {
                "readerhighlight_tap",
                "readermenu_tap",
                "tap_forward",
                "tap_backward",
            },
            handler = function(ges)
                if not self.is_placing then return false end
                self:placeSticker(ges.pos.x, ges.pos.y)
                self.is_placing = false
                return true
            end,
        },
    })
end

--- Place the selected sticker centered on the tap coordinates.
function PageSticker:placeSticker(tap_x, tap_y)
    if not self.current_page or not self.selected_sticker then
        logger.warn("Sticker: placeSticker() called but no page or sticker selected",
                     "page:", self.current_page, "sticker:", self.selected_sticker)
        return
    end

    local size = self:getCurrentStickerSize()
    local cx = tap_x - math.floor(size / 2)
    local cy = tap_y - math.floor(size / 2)

    self.store:addSticker(self.current_page, cx, cy, size, size,
                          self.selected_sticker, self.current_rotation)

    UIManager:setDirty(self.view, "ui")
    logger.dbg("Sticker: placed on page", self.current_page,
               "at", tap_x, ",", tap_y,
               "-> offset", cx, ",", cy,
               "size:", size, "rotation:", self.current_rotation,
               "total on page:", self.store:getCountForPage(self.current_page))
end

function PageSticker:onStickerToggleVisibility()
    self.is_visible = not self.is_visible
    UIManager:setDirty(self.view, "ui")
    UIManager:show(InfoMessage:new{
        text = self.is_visible and _("Stickers visible.") or _("Stickers hidden."),
        timeout = 1,
    })
    logger.dbg("Sticker: visibility toggled to", self.is_visible)
    return true
end

--- Build size sub-menu items.
function PageSticker:buildSizeMenuItems()
    local items = {}
    local presets = { "small", "medium", "large", "xlarge" }
    local labels = {
        small  = _("Small (~100px)"),
        medium = _("Medium (~150px)"),
        large  = _("Large (~230px)"),
        xlarge = _("Extra large (~316px)"),
    }
    for _, preset in ipairs(presets) do
        table.insert(items, {
            text = labels[preset],
            checked_func = function() return self.current_size_preset == preset end,
            callback = function()
                self.current_size_preset = preset
                logger.dbg("Sticker: size preset changed to", preset)
            end,
        })
    end
    return items
end

--- Build rotation sub-menu items.
function PageSticker:buildRotationMenuItems()
    local items = {}
    local angles = { 0, 90, 180, 270 }
    local labels = {
        [0]   = _("0° (no rotation)"),
        [90]  = _("90° clockwise"),
        [180] = _("180° (upside down)"),
        [270] = _("270° clockwise"),
    }
    for _, angle in ipairs(angles) do
        table.insert(items, {
            text = labels[angle],
            checked_func = function() return self.current_rotation == angle end,
            callback = function()
                self.current_rotation = angle
                logger.dbg("Sticker: rotation changed to", angle)
            end,
        })
    end
    return items
end

function PageSticker:addToMainMenu(menu_items)
    menu_items.sticker = {
        text = _("Page Stickers"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Place sticker"),
                callback = function()
                    self:onStickerStartPlacement()
                end,
            },
            {
                text = _("Sticker size"),
                sub_item_table_func = function()
                    return self:buildSizeMenuItems()
                end,
            },
            {
                text = _("Sticker rotation"),
                sub_item_table_func = function()
                    return self:buildRotationMenuItems()
                end,
            },
            {
                text = _("Show stickers"),
                checked_func = function() return self.is_visible end,
                callback = function()
                    self:onStickerToggleVisibility()
                end,
            },
            {
                text = _("Undo last sticker on this page"),
                callback = function()
                    if self.current_page then
                        self.store:removeLastSticker(self.current_page)
                        UIManager:setDirty(self.view, "ui")
                        logger.dbg("Sticker: undo on page", self.current_page,
                                   "remaining:", self.store:getCountForPage(self.current_page))
                    end
                end,
            },
            {
                text = _("Clear stickers on this page"),
                callback = function()
                    if self.current_page then
                        local count = self.store:clearPage(self.current_page)
                        UIManager:setDirty(self.view, "ui")
                        logger.dbg("Sticker: cleared", count, "stickers from page", self.current_page)
                    end
                end,
            },
            {
                text = _("Clear all stickers in this book"),
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    UIManager:show(ConfirmBox:new{
                        text = _("Remove all stickers from this book?"),
                        ok_text = _("Clear all"),
                        ok_callback = function()
                            local count = self.store:clearAll()
                            UIManager:setDirty(self.view, "ui")
                            logger.dbg("Sticker: cleared all", count, "stickers from book")
                        end,
                    })
                end,
            },
        },
    }
end

function PageSticker:onCloseWidget()
    local count = 0
    for _, bb in pairs(self.sticker_cache) do
        if bb and bb.free then
            bb:free()
            count = count + 1
        end
    end
    self.sticker_cache = {}
    logger.dbg("Sticker: onCloseWidget(), freed", count, "cached images")
end

return PageSticker
