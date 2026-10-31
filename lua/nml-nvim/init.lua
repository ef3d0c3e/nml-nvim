local M = {}

---@class nml.Options
---@field lsp? boolean Register and enable the server as `nml` (default true).
---@field cmd? string[] The server's command (default `{ "nml", "lsp" }`).
---@field luals? string|false The path of LuaLS, or `false` to go without it.
---@field conceal? boolean Draw markers, bullets, checkboxes, quotes and code headers (default true).
---@field style? boolean Highlight emphasis, headings, links and code (default true).
---@field code? boolean Highlight code blocks with their language's syntax (default true).

---@type nml.Options
M.options = { lsp = true, conceal = true, style = true, code = true }

--- Optional: the extras work without it, for a server registered by other means.
---@param opts? nml.Options
function M.setup(opts)
	M.options = vim.tbl_extend("force", M.options, opts or {})
	if not M.options.lsp then
		return
	end
	local config = {}
	if M.options.cmd then
		config.cmd = M.options.cmd
	end
	if M.options.luals ~= nil then
		config.init_options = { luals = M.options.luals }
	end
	vim.lsp.config("nml", config)
	vim.lsp.enable("nml")
end

--- The buffers each client's extras are attached to.
local attached = {}

--- Attaches the extras of the NML server to a buffer: called on `LspAttach`.
---@param client vim.lsp.Client
---@param bufnr integer
function M.attach(client, bufnr)
	attached[client.id] = attached[client.id] or {}
	if attached[client.id][bufnr] then
		return
	end
	attached[client.id][bufnr] = true

	local extras = {}
	for _, name in ipairs({ "conceal", "style", "code" }) do
		if M.options[name] then
			extras[#extras + 1] = require("nml-nvim." .. name)
		end
	end
	for _, extra in ipairs(extras) do
		extra.setup(bufnr)
	end
	local function update()
		for _, extra in ipairs(extras) do
			extra.update(client, bufnr)
		end
	end
	require("nml-nvim.util").on_change(client, bufnr, update)
	update()
end

--- Forgets a buffer whose client detached, or that was unloaded.
---@param client_id integer
---@param bufnr integer
function M.detach(client_id, bufnr)
	if attached[client_id] then
		attached[client_id][bufnr] = nil
	end
	for _, name in ipairs({ "conceal", "style", "code" }) do
		require("nml-nvim." .. name).clear(bufnr)
	end
end

return M
