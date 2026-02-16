local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local RenderImage = require("ui/renderimage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = require("device").screen
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")

local PageSticker = WidgetContainer:extend{
    name = "sticker",
    is_doc_only = true,
    stickers = nil,         -- per-page sticker data: { [pageno] = { {x, y, w, h, img}, ... } }
    sticker_cache = nil,    -- cached BlitBuffers keyed by path|w|h
    current_page = nil,
    is_placing = false,
    is_visible = true,
    selected_sticker = nil, -- path to the sticker image to place
    sticker_size = nil,     -- size in pixels (computed from screen width)
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
    self.stickers = {}
    self.sticker_cache = {}
    self.sticker_size = math.floor(Screen:getWidth() * 0.12)
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function PageSticker:onReaderReady()
    self.view:registerViewModule("sticker", self)
end

function PageSticker:onReadSettings(config)
    self.stickers = config:readSetting("sticker_data") or {}
    self.is_visible = config:readSetting("sticker_visible")
    if self.is_visible == nil then
        self.is_visible = true
    end
end

function PageSticker:onSaveSettings()
    self.ui.doc_settings:saveSetting("sticker_data", self.stickers)
    self.ui.doc_settings:saveSetting("sticker_visible", self.is_visible)
end

function PageSticker:onPageUpdate(pageno)
    self.current_page = pageno
end

--- Load and cache a sticker image as a BlitBuffer.
function PageSticker:getStickerBB(img_path, w, h)
    local key = img_path .. "|" .. tostring(w) .. "|" .. tostring(h)
    if not self.sticker_cache[key] then
        local bb = RenderImage:renderImageFile(img_path, false, w, h)
        if bb then
            self.sticker_cache[key] = bb
        else
            logger.warn("Sticker: failed to load image:", img_path)
        end
    end
    return self.sticker_cache[key]
end

--- Paint all stickers for the current page onto the screen buffer.
function PageSticker:paintTo(bb, x, y)
    if not self.is_visible or not self.current_page then return end
    local page_stickers = self.stickers[self.current_page]
    if not page_stickers then return end

    for _, s in ipairs(page_stickers) do
        local sticker_bb = self:getStickerBB(s.img, s.w, s.h)
        if sticker_bb then
            local dest_x = x + s.x
            local dest_y = y + s.y
            -- Use alpha blending for PNG transparency support
            bb:alphablitFrom(sticker_bb, dest_x, dest_y, 0, 0, s.w, s.h)
        end
    end
end

--- Scan the stickers directory and return a list of available sticker paths.
function PageSticker:getAvailableStickers()
    local sticker_dir = self.path .. "/stickers"
    local stickers = {}
    local ok, iter, dir_obj = pcall(lfs.dir, sticker_dir)
    if not ok then
        logger.warn("Sticker: cannot read stickers directory:", sticker_dir)
        return stickers
    end
    for entry in iter, dir_obj do
        if entry ~= "." and entry ~= ".." then
            local ext = entry:lower():match("%.(%w+)$")
            if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp" then
                table.insert(stickers, {
                    path = sticker_dir .. "/" .. entry,
                    name = entry:match("^(.+)%..+$") or entry,
                })
            end
        end
    end
    table.sort(stickers, function(a, b) return a.name < b.name end)
    return stickers
end

--- Show a menu to pick which sticker to place, then enter placement mode.
function PageSticker:onStickerStartPlacement()
    local available = self:getAvailableStickers()
    if #available == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No stickers found.\n\nAdd PNG or JPG images to:\nsticker.koplugin/stickers/"),
        })
        return true
    end

    local buttons = {}
    for _, s in ipairs(available) do
        table.insert(buttons, {{
            text = s.name,
            callback = function()
                self.selected_sticker = s.path
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
    UIManager:show(InfoMessage:new{
        text = _("Tap anywhere on the page to place the sticker."),
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
    if not self.current_page or not self.selected_sticker then return end

    local w = self.sticker_size
    local h = self.sticker_size

    local sticker = {
        x = tap_x - math.floor(w / 2),
        y = tap_y - math.floor(h / 2),
        w = w,
        h = h,
        img = self.selected_sticker,
    }

    if not self.stickers[self.current_page] then
        self.stickers[self.current_page] = {}
    end
    table.insert(self.stickers[self.current_page], sticker)

    UIManager:setDirty(self.view, "ui")
    logger.dbg("Sticker: placed on page", self.current_page, "at", tap_x, tap_y)
end

function PageSticker:onStickerToggleVisibility()
    self.is_visible = not self.is_visible
    UIManager:setDirty(self.view, "ui")
    UIManager:show(InfoMessage:new{
        text = self.is_visible and _("Stickers visible.") or _("Stickers hidden."),
        timeout = 1,
    })
    return true
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
                text = _("Show stickers"),
                checked_func = function() return self.is_visible end,
                callback = function()
                    self:onStickerToggleVisibility()
                end,
            },
            {
                text = _("Undo last sticker on this page"),
                callback = function()
                    if self.current_page and self.stickers[self.current_page] then
                        table.remove(self.stickers[self.current_page])
                        if #self.stickers[self.current_page] == 0 then
                            self.stickers[self.current_page] = nil
                        end
                        UIManager:setDirty(self.view, "ui")
                    end
                end,
            },
            {
                text = _("Clear stickers on this page"),
                callback = function()
                    if self.current_page then
                        self.stickers[self.current_page] = nil
                        UIManager:setDirty(self.view, "ui")
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
                            self.stickers = {}
                            UIManager:setDirty(self.view, "ui")
                        end,
                    })
                end,
            },
        },
    }
end

function PageSticker:onCloseWidget()
    for _, bb in pairs(self.sticker_cache) do
        if bb and bb.free then
            bb:free()
        end
    end
    self.sticker_cache = {}
end

return PageSticker
