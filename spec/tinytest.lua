--- tinytest: minimal pure-Lua test runner.
-- No dependencies — runs with any Lua 5.1+.

local M = {}

local tests = {}
local current_suite = ""
local passed = 0
local failed = 0
local errors = {}

function M.describe(name, fn)
    local prev = current_suite
    current_suite = current_suite == "" and name or (current_suite .. " > " .. name)
    fn()
    current_suite = prev
end

function M.it(name, fn)
    local full_name = current_suite .. " > " .. name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        io.write("  PASS  " .. full_name .. "\n")
    else
        failed = failed + 1
        table.insert(errors, { name = full_name, err = tostring(err) })
        io.write("  FAIL  " .. full_name .. "\n")
        io.write("        " .. tostring(err) .. "\n")
    end
end

--- Assertions

function M.assert_equal(expected, actual, msg)
    if expected ~= actual then
        local info = msg and (msg .. ": ") or ""
        error(info .. "expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function M.assert_true(val, msg)
    if not val then
        error((msg or "expected true") .. ", got " .. tostring(val), 2)
    end
end

function M.assert_false(val, msg)
    if val then
        error((msg or "expected false") .. ", got " .. tostring(val), 2)
    end
end

function M.assert_nil(val, msg)
    if val ~= nil then
        error((msg or "expected nil") .. ", got " .. tostring(val), 2)
    end
end

function M.assert_not_nil(val, msg)
    if val == nil then
        error(msg or "expected non-nil value, got nil", 2)
    end
end

function M.assert_table_len(tbl, expected_len, msg)
    local actual = #tbl
    if actual ~= expected_len then
        local info = msg and (msg .. ": ") or ""
        error(info .. "expected table length " .. expected_len .. ", got " .. actual, 2)
    end
end

function M.assert_error(fn, msg)
    local ok, _ = pcall(fn)
    if ok then
        error(msg or "expected function to raise an error, but it didn't", 2)
    end
end

--- Print summary and exit with appropriate code.
function M.summary()
    io.write("\n" .. string.rep("-", 50) .. "\n")
    io.write("Results: " .. passed .. " passed, " .. failed .. " failed\n")
    if #errors > 0 then
        io.write("\nFailures:\n")
        for i, e in ipairs(errors) do
            io.write("  " .. i .. ") " .. e.name .. "\n")
            io.write("     " .. e.err .. "\n")
        end
    end
    io.write(string.rep("-", 50) .. "\n")
    os.exit(failed > 0 and 1 or 0)
end

return M
