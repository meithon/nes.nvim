local M = {}

function M.setup(opts)
	opts = opts or {}

	vim.api.nvim_set_hl(0, "NesAdd", { link = "DiffAdd", default = true })
	vim.api.nvim_set_hl(0, "NesDelete", { link = "DiffDelete", default = true })
	vim.api.nvim_set_hl(0, "NesApply", { link = "DiffText", default = true })
end

setmetatable(M, {
	__index = function(_, key)
		if vim.startswith(key, "_") then
			-- hide private function
			return
		end
		local core = require("nes.core")
		if core[key] then
			return core[key]
		end
	end,
})

return M
