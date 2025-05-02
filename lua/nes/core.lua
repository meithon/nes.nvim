local Context = require("nes.context")

local M = {}

---@param filename string
---@param original_code string
---@param current_code string
---@param cursor [integer, integer] (1,0)-indexed (row, col)
---@param lang string
---@return fun() cancel
function M.fetch_suggestions(filename, original_code, current_code, cursor, lang, callback)
    if current_code == original_code then
        callback({})
        return function() end
    end
    local ctx = Context.new(filename, original_code, current_code, cursor, lang)
    local payload = ctx:payload()
    return require("nes.api").call(payload, function(stdout)
        local next_version = vim.trim(stdout)
        assert(next_version)
        local edits = ctx:generate_edits(next_version) or {}
        callback(edits)
    end)
end

return M
