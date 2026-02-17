--- Tests for main.lua (KOReader integration layer).
-- Uses mocked KOReader modules so no real device is needed.

-- Set up paths
package.path = "./sticker.koplugin/?.lua;./spec/?.lua;./spec/mocks/?.lua;" .. package.path

local t = require("spec.tinytest")
local mocks = require("mocks.koreader_mocks")

-- Install mocks BEFORE loading main.lua
mocks.install()

local PageSticker = require("main")

local describe, it = t.describe, t.it
local eq, is_true, is_false, is_nil, is_not_nil, tbl_len =
    t.assert_equal, t.assert_true, t.assert_false, t.assert_nil, t.assert_not_nil, t.assert_table_len

--- Helper: create a fully wired PageSticker instance.
local function make_plugin(opts)
    mocks.reset()
    mocks.UIManager:reset()
    mocks.RenderImage:reset()
    mocks.Dispatcher:reset()

    local ui = mocks.new_ui()
    local view = mocks.new_view()

    local plugin = PageSticker:new({
        ui = ui,
        view = view,
        path = "./sticker.koplugin",
    })

    return plugin, ui, view
end

-- ─── Tests ───

describe("PageSticker (main.lua)", function()

    describe("init", function()
        it("should create a StickerStore on init", function()
            local plugin = make_plugin()
            is_not_nil(plugin.store, "store should be created")
            eq(0, plugin.store:getTotalCount())
        end)

        it("should initialize sticker_cache as empty table", function()
            local plugin = make_plugin()
            is_not_nil(plugin.sticker_cache)
            local count = 0
            for _ in pairs(plugin.sticker_cache) do count = count + 1 end
            eq(0, count, "sticker_cache should start empty")
        end)

        it("should default size preset to medium", function()
            local plugin = make_plugin()
            eq("medium", plugin.current_size_preset)
        end)

        it("should default rotation to 0", function()
            local plugin = make_plugin()
            eq(0, plugin.current_rotation)
        end)

        it("should register dispatcher actions", function()
            make_plugin()
            local calls = mocks.get_calls("Dispatcher", "registerAction")
            is_true(#calls >= 2, "should register at least 2 actions")
        end)

        it("should register to main menu", function()
            make_plugin()
            local calls = mocks.get_calls("menu", "registerToMainMenu")
            eq(1, #calls, "should register to main menu once")
        end)
    end)

    describe("onReaderReady", function()
        it("should register as a view module", function()
            local plugin, _, view = make_plugin()
            plugin:onReaderReady()
            is_not_nil(view.view_modules["sticker"], "should register 'sticker' view module")
        end)
    end)

    describe("onPageUpdate", function()
        it("should track current page", function()
            local plugin = make_plugin()
            is_nil(plugin.current_page)
            plugin:onPageUpdate(42)
            eq(42, plugin.current_page)
            plugin:onPageUpdate(7)
            eq(7, plugin.current_page)
        end)
    end)

    describe("settings round-trip", function()
        it("should save and restore sticker data via doc_settings", function()
            local plugin, ui = make_plugin()

            -- Place some stickers
            plugin.current_page = 1
            plugin.selected_sticker = "/img/heart.png"
            plugin.sticker_size = 50
            plugin:placeSticker(100, 200)
            plugin:placeSticker(300, 400)
            plugin.current_page = 3
            plugin:placeSticker(50, 60)

            -- Save
            plugin:onSaveSettings()

            -- Create a new plugin and restore
            local plugin2 = make_plugin()
            local config = ui.doc_settings
            plugin2:onReadSettings(config)

            eq(3, plugin2.store:getTotalCount(), "should restore all stickers")
            tbl_len(plugin2.store:getStickersForPage(1), 2)
            tbl_len(plugin2.store:getStickersForPage(3), 1)
        end)

        it("should save and restore visibility setting", function()
            local plugin, ui = make_plugin()
            plugin.is_visible = false
            plugin:onSaveSettings()

            local plugin2 = make_plugin()
            plugin2:onReadSettings(ui.doc_settings)
            is_false(plugin2.is_visible)
        end)

        it("should default visibility to true when not saved", function()
            local plugin = make_plugin()
            plugin:onReadSettings(mocks.new_doc_settings())
            is_true(plugin.is_visible)
        end)
    end)

    describe("placeSticker", function()
        it("should add sticker centered on tap coordinates using current preset", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin.selected_sticker = "/img/star.png"
            plugin.current_size_preset = "medium"

            plugin:placeSticker(500, 600)

            local size = plugin:getCurrentStickerSize()
            local stickers = plugin.store:getStickersForPage(1)
            tbl_len(stickers, 1)
            eq(500 - math.floor(size / 2), stickers[1].x, "x should be centered")
            eq(600 - math.floor(size / 2), stickers[1].y, "y should be centered")
            eq(size, stickers[1].w)
            eq(size, stickers[1].h)
            eq("/img/star.png", stickers[1].img)
        end)

        it("should store the current rotation with the placed sticker", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin.selected_sticker = "/img/star.png"
            plugin.current_rotation = 90

            plugin:placeSticker(100, 200)

            local stickers = plugin.store:getStickersForPage(1)
            eq(90, stickers[1].rotation, "should save rotation=90")
        end)

        it("should use different sizes for different presets", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin.selected_sticker = "/img/star.png"

            plugin.current_size_preset = "small"
            plugin:placeSticker(100, 100)
            local small_w = plugin.store:getStickersForPage(1)[1].w

            plugin.current_size_preset = "large"
            plugin:placeSticker(200, 200)
            local large_w = plugin.store:getStickersForPage(1)[2].w

            is_true(large_w > small_w, "large preset should be bigger than small")
        end)

        it("should not place when no page is set", function()
            local plugin = make_plugin()
            plugin.selected_sticker = "/img/star.png"
            plugin:placeSticker(100, 200)
            eq(0, plugin.store:getTotalCount())
        end)

        it("should not place when no sticker is selected", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin:placeSticker(100, 200)
            eq(0, plugin.store:getTotalCount())
        end)

        it("should request screen refresh after placing", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin.selected_sticker = "/img/star.png"
            mocks.reset()

            plugin:placeSticker(100, 200)

            local calls = mocks.get_calls("UIManager", "setDirty")
            is_true(#calls > 0, "should call setDirty after placing")
        end)
    end)

    describe("paintTo", function()
        it("should not paint when not visible", function()
            local plugin = make_plugin()
            plugin.is_visible = false
            plugin.current_page = 1
            plugin.store:addSticker(1, 10, 20, 50, 50, "/img/a.png")

            mocks.reset()
            local bb = mocks.new_blitbuffer()
            plugin:paintTo(bb, 0, 0)

            local calls = mocks.get_calls("BlitBuffer", "alphablitFrom")
            eq(0, #calls, "should not paint when hidden")
        end)

        it("should not paint when no current page", function()
            local plugin = make_plugin()
            plugin.current_page = nil
            plugin.store:addSticker(1, 10, 20, 50, 50, "/img/a.png")

            mocks.reset()
            local bb = mocks.new_blitbuffer()
            plugin:paintTo(bb, 0, 0)

            local calls = mocks.get_calls("BlitBuffer", "alphablitFrom")
            eq(0, #calls)
        end)

        it("should paint stickers for current page using alphablitFrom", function()
            local plugin = make_plugin()
            plugin.current_page = 2

            -- Register images so RenderImage returns blitbuffers
            mocks.RenderImage:registerImage("/img/a.png")
            mocks.RenderImage:registerImage("/img/b.png")

            plugin.store:addSticker(2, 10, 20, 50, 50, "/img/a.png")
            plugin.store:addSticker(2, 30, 40, 60, 60, "/img/b.png")
            -- Sticker on a different page should not be painted
            plugin.store:addSticker(5, 70, 80, 50, 50, "/img/a.png")

            mocks.reset()
            local bb = mocks.new_blitbuffer()
            plugin:paintTo(bb, 0, 0)

            local calls = mocks.get_calls("RenderImage", "renderImageFile")
            eq(2, #calls, "should load 2 images (only current page)")
        end)

        it("should offset sticker positions by the view origin", function()
            local plugin = make_plugin()
            plugin.current_page = 1

            mocks.RenderImage:registerImage("/img/a.png")
            plugin.store:addSticker(1, 100, 200, 50, 50, "/img/a.png")

            mocks.reset()
            local bb = mocks.new_blitbuffer()
            plugin:paintTo(bb, 10, 20)  -- view offset

            local calls = mocks.get_calls("BlitBuffer", "alphablitFrom")
            eq(1, #calls)
            -- dest_x = offset_x + sticker_x = 10 + 100 = 110
            eq(110, calls[1].args[1], "dest_x should include view offset")
            -- dest_y = offset_y + sticker_y = 20 + 200 = 220
            eq(220, calls[1].args[2], "dest_y should include view offset")
        end)

        it("should skip stickers with missing images", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            -- Don't register "/img/missing.png" in RenderImage
            plugin.store:addSticker(1, 10, 20, 50, 50, "/img/missing.png")

            mocks.reset()
            local bb = mocks.new_blitbuffer()
            plugin:paintTo(bb, 0, 0)

            local calls = mocks.get_calls("BlitBuffer", "alphablitFrom")
            eq(0, #calls, "should not blit for missing images")
            local warns = mocks.get_calls("logger", "warn")
            is_true(#warns > 0, "should log a warning for missing image")
        end)
    end)

    describe("getStickerBB caching", function()
        it("should cache loaded images by path and size", function()
            local plugin = make_plugin()
            mocks.RenderImage:registerImage("/img/a.png")

            local bb1 = plugin:getStickerBB("/img/a.png", 50, 50)
            is_not_nil(bb1)

            mocks.reset()
            local bb2 = plugin:getStickerBB("/img/a.png", 50, 50)
            is_not_nil(bb2)

            -- Should NOT have called renderImageFile again
            local calls = mocks.get_calls("RenderImage", "renderImageFile")
            eq(0, #calls, "should use cache on second call")
        end)

        it("should load separately for different sizes", function()
            local plugin = make_plugin()
            mocks.RenderImage:registerImage("/img/a.png")

            plugin:getStickerBB("/img/a.png", 50, 50)
            mocks.reset()
            plugin:getStickerBB("/img/a.png", 100, 100)

            local calls = mocks.get_calls("RenderImage", "renderImageFile")
            eq(1, #calls, "should load again for different size")
        end)
    end)

    describe("onStickerToggleVisibility", function()
        it("should toggle visibility", function()
            local plugin = make_plugin()
            is_true(plugin.is_visible)

            plugin:onStickerToggleVisibility()
            is_false(plugin.is_visible)

            plugin:onStickerToggleVisibility()
            is_true(plugin.is_visible)
        end)

        it("should show a toast message", function()
            local plugin = make_plugin()
            mocks.reset()
            plugin:onStickerToggleVisibility()

            local calls = mocks.get_calls("InfoMessage", "new")
            is_true(#calls > 0, "should show an InfoMessage")
        end)
    end)

    describe("addToMainMenu", function()
        it("should add menu entries with size and rotation sub-menus", function()
            local plugin = make_plugin()
            local menu_items = {}
            plugin:addToMainMenu(menu_items)

            is_not_nil(menu_items.sticker, "should add 'sticker' menu item")
            is_not_nil(menu_items.sticker.sub_item_table, "should have sub-items")
            -- Place, Size, Rotation, Show, Undo, Clear page, Clear all = 7
            is_true(#menu_items.sticker.sub_item_table >= 7, "should have at least 7 sub-items")
        end)

        it("undo callback should remove last sticker from store", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin.store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            plugin.store:addSticker(1, 30, 40, 50, 50, "/img/b.png")

            local menu_items = {}
            plugin:addToMainMenu(menu_items)

            -- Find the undo item (5th sub-item: Place, Size, Rotation, Show, Undo)
            local undo_item = menu_items.sticker.sub_item_table[5]
            undo_item.callback()

            eq(1, plugin.store:getCountForPage(1), "should have 1 sticker after undo")
        end)

        it("clear page callback should clear current page", function()
            local plugin = make_plugin()
            plugin.current_page = 1
            plugin.store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            plugin.store:addSticker(1, 30, 40, 50, 50, "/img/b.png")

            local menu_items = {}
            plugin:addToMainMenu(menu_items)

            -- Clear page is the 6th sub-item
            local clear_item = menu_items.sticker.sub_item_table[6]
            clear_item.callback()

            eq(0, plugin.store:getCountForPage(1))
        end)
    end)

    describe("settings round-trip (size and rotation)", function()
        it("should save and restore size preset", function()
            local plugin, ui = make_plugin()
            plugin.current_size_preset = "large"
            plugin:onSaveSettings()

            local plugin2 = make_plugin()
            plugin2:onReadSettings(ui.doc_settings)
            eq("large", plugin2.current_size_preset)
        end)

        it("should save and restore rotation", function()
            local plugin, ui = make_plugin()
            plugin.current_rotation = 180
            plugin:onSaveSettings()

            local plugin2 = make_plugin()
            plugin2:onReadSettings(ui.doc_settings)
            eq(180, plugin2.current_rotation)
        end)

        it("should default size to medium when not saved", function()
            local plugin = make_plugin()
            plugin:onReadSettings(mocks.new_doc_settings())
            eq("medium", plugin.current_size_preset)
        end)

        it("should default rotation to 0 when not saved", function()
            local plugin = make_plugin()
            plugin:onReadSettings(mocks.new_doc_settings())
            eq(0, plugin.current_rotation)
        end)
    end)

    describe("getCurrentStickerSize", function()
        it("should return pixel size based on preset and screen width", function()
            local plugin = make_plugin()
            plugin.current_size_preset = "small"
            local small = plugin:getCurrentStickerSize()
            plugin.current_size_preset = "xlarge"
            local xlarge = plugin:getCurrentStickerSize()

            is_true(small > 0)
            is_true(xlarge > small, "xlarge should be bigger than small")
        end)

        it("should fall back to medium for invalid preset", function()
            local plugin = make_plugin()
            plugin.current_size_preset = "nonexistent"
            local size = plugin:getCurrentStickerSize()
            local expected = math.floor(1264 * 0.12)  -- medium on 1264px screen
            eq(expected, size)
        end)
    end)

    describe("buildSizeMenuItems", function()
        it("should return 4 size presets", function()
            local plugin = make_plugin()
            local items = plugin:buildSizeMenuItems()
            tbl_len(items, 4)
        end)

        it("should check the current preset", function()
            local plugin = make_plugin()
            plugin.current_size_preset = "large"
            local items = plugin:buildSizeMenuItems()

            -- Find the one that's checked
            local checked_count = 0
            for _, item in ipairs(items) do
                if item.checked_func() then
                    checked_count = checked_count + 1
                end
            end
            eq(1, checked_count, "exactly one preset should be checked")
        end)
    end)

    describe("buildRotationMenuItems", function()
        it("should return 4 rotation options", function()
            local plugin = make_plugin()
            local items = plugin:buildRotationMenuItems()
            tbl_len(items, 4)
        end)

        it("should check the current rotation", function()
            local plugin = make_plugin()
            plugin.current_rotation = 270
            local items = plugin:buildRotationMenuItems()

            local checked_count = 0
            for _, item in ipairs(items) do
                if item.checked_func() then
                    checked_count = checked_count + 1
                end
            end
            eq(1, checked_count, "exactly one rotation should be checked")
        end)
    end)

    describe("onCloseWidget", function()
        it("should free all cached blitbuffers", function()
            local plugin = make_plugin()
            mocks.RenderImage:registerImage("/img/a.png")
            mocks.RenderImage:registerImage("/img/b.png")

            plugin:getStickerBB("/img/a.png", 50, 50)
            plugin:getStickerBB("/img/b.png", 60, 60)

            mocks.reset()
            plugin:onCloseWidget()

            local calls = mocks.get_calls("BlitBuffer", "free")
            eq(2, #calls, "should free 2 cached blitbuffers")

            -- Cache should be empty after close
            local count = 0
            for _ in pairs(plugin.sticker_cache) do count = count + 1 end
            eq(0, count, "cache should be empty after close")
        end)
    end)

    describe("enterPlacementMode", function()
        it("should set is_placing flag", function()
            local plugin = make_plugin()
            is_false(plugin.is_placing)
            plugin:enterPlacementMode()
            is_true(plugin.is_placing)
        end)

        it("should register touch zones on ui", function()
            local plugin, ui = make_plugin()
            mocks.reset()
            plugin:enterPlacementMode()

            local calls = mocks.get_calls("ui", "registerTouchZones")
            eq(1, #calls, "should register touch zones")
        end)

        it("should show placement instructions", function()
            local plugin = make_plugin()
            mocks.reset()
            plugin:enterPlacementMode()

            local calls = mocks.get_calls("InfoMessage", "new")
            is_true(#calls > 0, "should show placement instructions")
        end)
    end)

end)

t.summary()
