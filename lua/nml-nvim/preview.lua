-- The live preview: the language server serves the workspace's pages to the browser, which
-- follows the edits and the cursor.
local M = {}

--- The NML language server of a buffer, if it has the preview.
---@param bufnr integer
---@return vim.lsp.Client?
local function nml_client(bufnr)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local provider = client.server_capabilities.executeCommandProvider
		if provider and vim.tbl_contains(provider.commands or {}, "nml.preview") then
			return client
		end
	end
end

--- The clients whose preview runs, by id.
local previewing = {}

--- Starts the preview of the buffer's page, and opens it in the browser.
---@param bufnr integer
function M.open(bufnr)
	local client = nml_client(bufnr)
	if not client then
		vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
		return
	end
	local command = { title = "Preview", command = "nml.preview", arguments = { vim.uri_from_bufnr(bufnr) } }
	client:exec_cmd(command, { bufnr = bufnr }, function(err, url)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
			return
		end
		previewing[client.id] = true
		local _, open_err = vim.ui.open(url)
		if open_err then
			vim.notify(string.format("Preview at %s (%s)", url, open_err), vim.log.levels.INFO)
		end
		if require("nml-nvim").options.follow then
			M.follow()
		end
	end)
end

local timer
--- The last position sent, by buffer: only a new line is sent.
local sent = {}

--- Sends where the cursor is to the servers whose preview runs.
local function send_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].filetype ~= "nml" then
		return
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	if sent[bufnr] == line then
		return
	end
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if previewing[client.id] then
			sent[bufnr] = line
			local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
			client:notify("nml/cursor", params)
		end
	end
end

local following = false

--- Makes the previews follow the cursor, once the cursor rests.
function M.follow()
	if following then
		return
	end
	following = true
	timer = assert(vim.uv.new_timer())
	local group = vim.api.nvim_create_augroup("nml-nvim-preview", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
		group = group,
		callback = function(args)
			if vim.bo[args.buf].filetype ~= "nml" then
				return
			end
			timer:stop()
			timer:start(100, 0, vim.schedule_wrap(send_cursor))
		end,
	})
	vim.api.nvim_create_autocmd("BufUnload", {
		group = group,
		callback = function(args)
			sent[args.buf] = nil
		end,
	})
	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(args)
			previewing[args.data.client_id] = nil
		end,
	})
end

return M
