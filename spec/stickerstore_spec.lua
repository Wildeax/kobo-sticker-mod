--- Tests for StickerStore (pure data layer).

-- Add plugin directory to path so require("stickerstore") works
package.path = "./sticker.koplugin/?.lua;" .. package.path

local t = require("spec.tinytest")
local StickerStore = require("stickerstore")

local describe, it = t.describe, t.it
local eq, is_true, is_nil, is_not_nil, tbl_len =
    t.assert_equal, t.assert_true, t.assert_nil, t.assert_not_nil, t.assert_table_len

-- ─── Adding stickers ───

describe("StickerStore", function()

    describe("addSticker", function()
        it("should add a sticker to a page", function()
            local store = StickerStore:new()
            local ok = store:addSticker(1, 100, 200, 50, 50, "/img/heart.png")
            is_true(ok)

            local stickers = store:getStickersForPage(1)
            tbl_len(stickers, 1)
            eq(100, stickers[1].x)
            eq(200, stickers[1].y)
            eq(50, stickers[1].w)
            eq(50, stickers[1].h)
            eq("/img/heart.png", stickers[1].img)
        end)

        it("should add multiple stickers to the same page", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(1, 30, 40, 50, 50, "/img/b.png")
            store:addSticker(1, 50, 60, 50, 50, "/img/c.png")

            tbl_len(store:getStickersForPage(1), 3)
        end)

        it("should add stickers to different pages independently", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(5, 30, 40, 50, 50, "/img/b.png")
            store:addSticker(5, 50, 60, 50, 50, "/img/c.png")

            tbl_len(store:getStickersForPage(1), 1)
            tbl_len(store:getStickersForPage(5), 2)
            tbl_len(store:getStickersForPage(3), 0, "page with no stickers")
        end)

        it("should reject missing fields", function()
            local store = StickerStore:new()
            local ok, err = store:addSticker(nil, 10, 20, 50, 50, "/img/a.png")
            eq(false, ok)

            ok, err = store:addSticker(1, 10, 20, 50, nil, "/img/a.png")
            eq(false, ok)

            ok, err = store:addSticker(1, 10, 20, 50, 50, nil)
            eq(false, ok)
        end)

        it("should reject invalid page numbers", function()
            local store = StickerStore:new()
            local ok, err = store:addSticker(0, 10, 20, 50, 50, "/img/a.png")
            eq(false, ok)

            ok, err = store:addSticker(-1, 10, 20, 50, 50, "/img/a.png")
            eq(false, ok)

            ok, err = store:addSticker("abc", 10, 20, 50, 50, "/img/a.png")
            eq(false, ok)
        end)
    end)

    -- ─── Removing / undo ───

    describe("removeLastSticker", function()
        it("should remove the last sticker on a page", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/first.png")
            store:addSticker(1, 30, 40, 50, 50, "/img/second.png")

            local removed = store:removeLastSticker(1)
            is_not_nil(removed)
            eq("/img/second.png", removed.img, "should remove last added")
            tbl_len(store:getStickersForPage(1), 1)
            eq("/img/first.png", store:getStickersForPage(1)[1].img)
        end)

        it("should return nil when page has no stickers", function()
            local store = StickerStore:new()
            is_nil(store:removeLastSticker(1))
        end)

        it("should clean up empty page entry after last sticker removed", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:removeLastSticker(1)

            -- Internal pages table should not have a key for page 1
            is_nil(store.pages[1], "page entry should be cleaned up")
            tbl_len(store:getStickersForPage(1), 0)
        end)
    end)

    -- ─── Clear page ───

    describe("clearPage", function()
        it("should remove all stickers from a page", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(1, 30, 40, 50, 50, "/img/b.png")
            store:addSticker(2, 50, 60, 50, 50, "/img/c.png")

            local count = store:clearPage(1)
            eq(2, count)
            tbl_len(store:getStickersForPage(1), 0)
            tbl_len(store:getStickersForPage(2), 1, "other pages unaffected")
        end)

        it("should return 0 for empty page", function()
            local store = StickerStore:new()
            eq(0, store:clearPage(99))
        end)
    end)

    -- ─── Clear all ───

    describe("clearAll", function()
        it("should remove all stickers from all pages", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(2, 30, 40, 50, 50, "/img/b.png")
            store:addSticker(3, 50, 60, 50, 50, "/img/c.png")

            local count = store:clearAll()
            eq(3, count)
            tbl_len(store:getStickersForPage(1), 0)
            tbl_len(store:getStickersForPage(2), 0)
            tbl_len(store:getStickersForPage(3), 0)
        end)

        it("should return 0 when already empty", function()
            local store = StickerStore:new()
            eq(0, store:clearAll())
        end)
    end)

    -- ─── Counting ───

    describe("counting", function()
        it("should count stickers on a page", function()
            local store = StickerStore:new()
            eq(0, store:getCountForPage(1))
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(1, 30, 40, 50, 50, "/img/b.png")
            eq(2, store:getCountForPage(1))
        end)

        it("should count total stickers across all pages", function()
            local store = StickerStore:new()
            eq(0, store:getTotalCount())
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(2, 30, 40, 50, 50, "/img/b.png")
            store:addSticker(2, 50, 60, 50, 50, "/img/c.png")
            eq(3, store:getTotalCount())
        end)

        it("should list pages with stickers, sorted", function()
            local store = StickerStore:new()
            store:addSticker(5, 10, 20, 50, 50, "/img/a.png")
            store:addSticker(1, 30, 40, 50, 50, "/img/b.png")
            store:addSticker(10, 50, 60, 50, 50, "/img/c.png")

            local pages = store:getPagesWithStickers()
            tbl_len(pages, 3)
            eq(1, pages[1])
            eq(5, pages[2])
            eq(10, pages[3])
        end)
    end)

    -- ─── Serialization ───

    describe("serialize / deserialize", function()
        it("should round-trip sticker data", function()
            local store = StickerStore:new()
            store:addSticker(1, 100, 200, 50, 50, "/img/heart.png")
            store:addSticker(1, 300, 400, 60, 60, "/img/star.png")
            store:addSticker(3, 10, 20, 40, 40, "/img/cat.png")

            local data = store:serialize()

            local store2 = StickerStore:new()
            store2:deserialize(data)

            eq(store:getTotalCount(), store2:getTotalCount(), "total count should match")
            local s1 = store2:getStickersForPage(1)
            tbl_len(s1, 2)
            eq(100, s1[1].x)
            eq("/img/heart.png", s1[1].img)
            eq("/img/star.png", s1[2].img)
        end)

        it("should handle deserializing nil gracefully", function()
            local store = StickerStore:new()
            store:addSticker(1, 10, 20, 50, 50, "/img/a.png")
            store:deserialize(nil)
            eq(0, store:getTotalCount(), "should reset to empty on nil data")
        end)

        it("should handle deserializing non-table gracefully", function()
            local store = StickerStore:new()
            store:deserialize("garbage")
            eq(0, store:getTotalCount())
        end)
    end)

    -- ─── scanDirectory ───

    describe("scanDirectory", function()
        it("should find image files in a directory", function()
            -- Create temp directory with test files
            local tmp = os.tmpname()
            os.remove(tmp)  -- remove the file, we'll make a directory

            local dir = tmp .. "_stickers"
            local ok_lfs, lfs = pcall(require, "lfs")
            if not ok_lfs then
                io.write("    SKIP  scanDirectory tests (lfs not available)\n")
                return
            end

            lfs.mkdir(dir)
            -- Create dummy files
            for _, name in ipairs({"heart.png", "star.jpg", "cat.jpeg", "dog.webp", "readme.txt", "notes.md"}) do
                local f = io.open(dir .. "/" .. name, "w")
                if f then f:write("x") f:close() end
            end

            local stickers = StickerStore.scanDirectory(dir, lfs)
            tbl_len(stickers, 4, "should find 4 image files")

            -- Should be sorted by name
            eq("cat", stickers[1].name)
            eq("dog", stickers[2].name)
            eq("heart", stickers[3].name)
            eq("star", stickers[4].name)

            -- Paths should include directory
            is_true(stickers[1].path:find(dir, 1, true) ~= nil, "path should include dir")

            -- Cleanup
            for _, name in ipairs({"heart.png", "star.jpg", "cat.jpeg", "dog.webp", "readme.txt", "notes.md"}) do
                os.remove(dir .. "/" .. name)
            end
            lfs.rmdir(dir)
        end)

        it("should return empty list for non-existent directory", function()
            local ok_lfs, lfs = pcall(require, "lfs")
            if not ok_lfs then
                io.write("    SKIP  scanDirectory non-existent dir test (lfs not available)\n")
                return
            end
            local stickers, err = StickerStore.scanDirectory("/nonexistent/path/xyz", lfs)
            tbl_len(stickers, 0)
        end)

        it("should return empty list for directory with no images", function()
            local ok_lfs, lfs = pcall(require, "lfs")
            if not ok_lfs then
                io.write("    SKIP  scanDirectory no-images test (lfs not available)\n")
                return
            end

            local tmp = os.tmpname()
            os.remove(tmp)
            local dir = tmp .. "_empty"
            lfs.mkdir(dir)

            local f = io.open(dir .. "/readme.txt", "w")
            if f then f:write("x") f:close() end

            local stickers = StickerStore.scanDirectory(dir, lfs)
            tbl_len(stickers, 0)

            os.remove(dir .. "/readme.txt")
            lfs.rmdir(dir)
        end)
    end)

end)

t.summary()
