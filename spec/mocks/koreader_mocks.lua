--- Lightweight mocks for KOReader modules.
-- Allows main.lua to be loaded and tested without a real KOReader environment.

local M = {}

--- Tracks calls made to mocked objects for assertions.
M.call_log = {}

local function log_call(module, method, ...)
    table.insert(M.call_log, {
        module = module,
        method = method,
        args = {...},
    })
end

function M.reset()
    M.call_log = {}
end

function M.get_calls(module, method)
    local result = {}
    for _, c in ipairs(M.call_log) do
        if c.module == module and (method == nil or c.method == method) then
            table.insert(result, c)
        end
    end
    return result
end

--- Mock: Screen
M.Screen = {
    getWidth = function() return 1264 end,
    getHeight = function() return 1680 end,
    getDPI = function() return 300 end,
}

--- Mock: device
M.device = {
    screen = M.Screen,
    isKobo = function() return true end,
}

--- Mock: UIManager
M.UIManager = {
    _shown = {},
    show = function(self, widget, refreshtype)
        log_call("UIManager", "show", widget)
        table.insert(self._shown, widget)
    end,
    close = function(self, widget)
        log_call("UIManager", "close", widget)
        for i, w in ipairs(self._shown) do
            if w == widget then
                table.remove(self._shown, i)
                break
            end
        end
    end,
    setDirty = function(self, widget, refreshtype)
        log_call("UIManager", "setDirty", widget, refreshtype)
    end,
    reset = function(self)
        self._shown = {}
    end,
}

--- Mock: BlitBuffer
M.BlitBuffer = {
    alphablitFrom = function(self, src, dest_x, dest_y, src_x, src_y, w, h)
        log_call("BlitBuffer", "alphablitFrom", dest_x, dest_y, w, h)
    end,
    free = function(self)
        log_call("BlitBuffer", "free")
        self._freed = true
    end,
    _freed = false,
}

function M.new_blitbuffer()
    return {
        alphablitFrom = M.BlitBuffer.alphablitFrom,
        free = M.BlitBuffer.free,
        _freed = false,
    }
end

--- Mock: RenderImage
M.RenderImage = {
    _images = {},  -- path -> true (register paths that "exist")
    renderImageFile = function(self, path, grayscale, w, h)
        log_call("RenderImage", "renderImageFile", path, w, h)
        if self._images[path] then
            return M.new_blitbuffer()
        end
        return nil
    end,
    registerImage = function(self, path)
        self._images[path] = true
    end,
    reset = function(self)
        self._images = {}
    end,
}

--- Mock: logger
M.logger = {
    dbg = function(...) end,
    info = function(...) end,
    warn = function(...) log_call("logger", "warn", ...) end,
    err = function(...) log_call("logger", "err", ...) end,
}

--- Mock: gettext
M.gettext = function(s) return s end

--- Mock: Dispatcher
M.Dispatcher = {
    _actions = {},
    registerAction = function(self, id, opts)
        log_call("Dispatcher", "registerAction", id)
        self._actions[id] = opts
    end,
    reset = function(self)
        self._actions = {}
    end,
}

--- Mock: InfoMessage
M.InfoMessage = {
    new = function(self, opts)
        log_call("InfoMessage", "new", opts and opts.text)
        return { _type = "InfoMessage", text = opts and opts.text, timeout = opts and opts.timeout }
    end,
}

--- Mock: ConfirmBox
M.ConfirmBox = {
    new = function(self, opts)
        log_call("ConfirmBox", "new", opts and opts.text)
        return {
            _type = "ConfirmBox",
            text = opts and opts.text,
            ok_callback = opts and opts.ok_callback,
        }
    end,
}

--- Mock: ButtonDialogTitle
M.ButtonDialogTitle = {
    new = function(self, opts)
        log_call("ButtonDialogTitle", "new", opts and opts.title)
        return { _type = "ButtonDialogTitle", title = opts and opts.title, buttons = opts and opts.buttons }
    end,
}

--- Mock: WidgetContainer base class
M.WidgetContainer = {}
M.WidgetContainer.__index = M.WidgetContainer

function M.WidgetContainer:extend(defaults)
    local cls = setmetatable(defaults or {}, { __index = self })
    cls.__index = cls
    return cls
end

function M.WidgetContainer:new(opts)
    local o = setmetatable(opts or {}, { __index = self })
    if o.init then
        o:init()
    end
    return o
end

--- Mock: doc_settings
function M.new_doc_settings()
    local data = {}
    return {
        readSetting = function(self, key)
            return data[key]
        end,
        saveSetting = function(self, key, value)
            data[key] = value
        end,
        _data = data,
    }
end

--- Mock: view
function M.new_view()
    local view_modules = {}
    return {
        view_modules = view_modules,
        registerViewModule = function(self, name, widget)
            log_call("view", "registerViewModule", name)
            self.view_modules[name] = widget
        end,
    }
end

--- Mock: menu
function M.new_menu()
    local registered = {}
    return {
        _registered = registered,
        registerToMainMenu = function(self, plugin)
            log_call("menu", "registerToMainMenu")
            table.insert(registered, plugin)
        end,
    }
end

--- Mock: ui (ReaderUI)
function M.new_ui()
    local ui = {
        menu = M.new_menu(),
        doc_settings = M.new_doc_settings(),
        registerTouchZones = function(self, zones)
            log_call("ui", "registerTouchZones", #zones)
            self._touch_zones = zones
        end,
        _touch_zones = {},
    }
    return ui
end

--- Install all mocks into package.loaded so require() picks them up.
function M.install()
    M.reset()
    M.UIManager:reset()
    M.RenderImage:reset()
    M.Dispatcher:reset()

    package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = 0 }
    package.loaded["dispatcher"] = M.Dispatcher
    package.loaded["ui/widget/infomessage"] = M.InfoMessage
    package.loaded["ui/widget/confirmbox"] = M.ConfirmBox
    package.loaded["ui/widget/buttondialogtitle"] = M.ButtonDialogTitle
    package.loaded["ui/renderimage"] = M.RenderImage
    package.loaded["ui/uimanager"] = M.UIManager
    package.loaded["ui/widget/container/widgetcontainer"] = M.WidgetContainer
    package.loaded["device"] = M.device
    package.loaded["logger"] = M.logger
    package.loaded["gettext"] = M.gettext
end

return M
