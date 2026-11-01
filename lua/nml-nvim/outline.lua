-- The outline: folding from the server's ranges, and the commands that promote, demote and
-- move a heading's section.
local M = {}

--- The NML language server of a buffer.
---@param bufnr integer
---@return vim.lsp.Client?
local function nml_client(bufnr)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local provider = client.server_capabilities.executeCommandProvider
		if provider and vim.tbl_contains(provider.commands or {}, "nml.promote") then
			return client
		end
	end
end

--- Folds the buffer's windows with the server's ranges, open at first.
---@param bufnr integer
function M.setup(bufnr)
	local function fold(win)
		vim.wo[win][0].foldmethod = "expr"
		vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
		vim.wo[win][0].foldlevel = 99
	end
	for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
		fold(win)
	end
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = vim.api.nvim_create_augroup("nml-nvim-fold-" .. bufnr, { clear = true }),
		buffer = bufnr,
		callback = function()
			fold(vim.api.nvim_get_current_win())
		end,
	})
end

--- Runs a structure command on the section at the cursor: `nml.promote`, `nml.demote`,
--- `nml.moveUp` or `nml.moveDown`.
---@param bufnr integer
---@param command string
function M.run(bufnr, command)
	local client = nml_client(bufnr)
	if not client then
		vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
		return
	end
	local line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local arguments = { vim.uri_from_bufnr(bufnr), line }
	client:exec_cmd({ title = command, command = command, arguments = arguments }, { bufnr = bufnr }, function(err)
		if err then
			vim.notify(err.message, vim.log.levels.WARN)
		end
	end)
end

return M
