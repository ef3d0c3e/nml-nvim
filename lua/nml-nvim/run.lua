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

--- The line (from 0) of the `:run` block under the cursor, or of the last one above it.
---@param bufnr integer
---@return integer?
local function block_line(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor, false)
	for line = #lines, 1, -1 do
		if lines[line]:match("^:run[%[ ]") or lines[line] == ":run" then
			return line - 1
		end
	end
	vim.notify("No `:run` block at or above the cursor", vim.log.levels.WARN)
end

--- Runs the `:run` block under the cursor, or the last one above it.
---@param bufnr integer
function M.run(bufnr)
	local line = block_line(bufnr)
	if line then
		exec(bufnr, "nml.run", { vim.uri_from_bufnr(bufnr), line })
	end
end

--- Shows everything a run printed in a split: what `nml.runOutput` answers.
---@param output table
local function show(output)
	local title = "Run"
	if output.name ~= vim.NIL and output.name then
		title = title .. " #" .. output.name
	end
	local status = output.status
	if output.duration_ms then
		local preposition = status == "completed" and "in" or "after"
		status = string.format("%s %s %d ms", status, preposition, output.duration_ms)
	end
	local lines = { string.format("%s with %s: %s", title, output.runner, status) }
	if output.files and #output.files > 0 then
		lines[#lines + 1] = "Files: " .. table.concat(output.files, ", ")
	end
	for _, stream in ipairs({ "stdout", "stderr" }) do
		local text = output[stream]
		if type(text) == "string" and text ~= "" then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "── " .. stream .. " ──"
			vim.list_extend(lines, vim.split(text:gsub("\n$", ""), "\n", { plain = true }))
		end
	end
	local name = "nml://run/" .. (output.name ~= vim.NIL and output.name or "output")
	local old = vim.fn.bufnr(name)
	if old ~= -1 then
		vim.api.nvim_buf_delete(old, { force = true })
	end
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close the run's output" })
end

--- Shows what the block under the cursor (or the last one above it) printed.
---@param bufnr integer
---@param line? integer The line of its `:run`, from 0.
function M.output(bufnr, line)
	line = line or block_line(bufnr)
	local client = nml_client(bufnr)
	if not line or not client then
		return
	end
	local command = { title = "Output", command = "nml.runOutput", arguments = { vim.uri_from_bufnr(bufnr), line } }
	client:exec_cmd(command, { bufnr = bufnr }, function(err, output)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
		elseif output.status == "not run" or output.status == "running" then
			vim.notify("The block has " .. (output.status == "running" and "not finished" or "not run"), vim.log.levels.INFO)
		else
			show(output)
		end
	end)
end

-- The `≡ Output` lens: shown in a split here, rather than by opening the files.
vim.lsp.commands["nml.showRunOutput"] = function(command, ctx)
	M.output(ctx.bufnr, command.arguments[2])
end

--- Runs the blocks of the buffer that have not completed.
---@param bufnr integer
function M.run_all(bufnr)
	exec(bufnr, "nml.runAll", { vim.uri_from_bufnr(bufnr) })
end

return M
