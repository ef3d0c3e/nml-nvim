-- `textDocument/style`: ranges to highlight, with a highlight group by name (`@markup.strong`).
local util = require("nml-nvim.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("nml-style")

function M.setup(_) end

function M.clear(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
	end
end

function M.update(client, bufnr)
	util.request(client, "textDocument/style", bufnr, function(result)
		M.clear(bufnr)
		for _, info in ipairs(result or {}) do
			local group = info.style.group
			if group then
				local range = info.range
				pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, range.start.line,
					util.byte_column(bufnr, range.start), {
						end_row = range["end"].line,
						end_col = util.byte_column(bufnr, range["end"]),
						hl_group = group,
						priority = 90,
					})
			end
		end
	end)
end

return M
