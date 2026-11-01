-- `:run` blocks: the code lenses of the server, which tell whether each block completed,
-- failed or has not run, and the commands that run them.
local M = {}

--- The NML language server of a buffer, if it runs blocks.
---@param bufnr integer
---@return vim.lsp.Client?
local function nml_client(bufnr)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local provider = client.server_capabilities.executeCommandProvider
		if provider and vim.tbl_contains(provider.commands or {}, "nml.run") then
			return client
		end
	end
end

--- Shows the code lenses of a buffer: Neovim keeps them up to date from 0.12, and they
--- are refreshed on edits before.
---@param client vim.lsp.Client
---@param bufnr integer
function M.setup(client, bufnr)
	if not client.server_capabilities.codeLensProvider then
		return
	end
	local codelens = vim.lsp.codelens
	if codelens.enable then
		codelens.enable(true, { bufnr = bufnr, client_id = client.id })
		return
	end
	local function refresh()
		codelens.refresh({ bufnr = bufnr })
	end
	vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
		group = vim.api.nvim_create_augroup("nml-nvim-run-" .. bufnr, { clear = true }),
		buffer = bufnr,
		callback = refresh,
	})
	refresh()
end

--- Sends a command to the server of the buffer, and reports its error.
---@param bufnr integer
---@param command string
---@param arguments any[]
local function exec(bufnr, command, arguments)
	local client = nml_client(bufnr)
	if not client then
		vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
		return
	end
	client:exec_cmd({ title = command, command = command, arguments = arguments }, { bufnr = bufnr }, function(err)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
		end
	end)
end

--- Runs the `:run` block under the cursor, or the last one above it.
---@param bufnr integer
function M.run(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor, false)
	for line = #lines, 1, -1 do
		if lines[line]:match("^:run[%[ ]") or lines[line] == ":run" then
			exec(bufnr, "nml.run", { vim.uri_from_bufnr(bufnr), line - 1 })
			return
		end
	end
	vim.notify("No `:run` block at or above the cursor", vim.log.levels.WARN)
end

--- Runs the blocks of the buffer that have not completed.
---@param bufnr integer
function M.run_all(bufnr)
	exec(bufnr, "nml.runAll", { vim.uri_from_bufnr(bufnr) })
end

return M
