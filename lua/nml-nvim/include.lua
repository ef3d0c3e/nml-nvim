-- The include context of an included file: the includer it is analysed in.
local M = {}

local function nml_client(bufnr)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client:supports_method("workspace/executeCommand")
			and vim.tbl_contains(client.server_capabilities.executeCommandProvider.commands or {}, "nml.includeContext")
		then
			return client
		end
	end
end

--- Lets the user choose the includer of the buffer's file, among those that include it.
---@param bufnr integer
function M.choose(bufnr)
	local client = nml_client(bufnr)
	if not client then
		vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
		return
	end
	local uri = vim.uri_from_bufnr(bufnr)
	client:request("nml/includeContexts", { textDocument = { uri = uri } }, function(err, result)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
			return
		end
		local candidates = result.candidates or {}
		if #candidates == 0 then
			vim.notify("No file includes this one", vim.log.levels.INFO)
			return
		end
		vim.ui.select(candidates, {
			prompt = "Analyse in",
			format_item = function(path)
				return path == result.current and path .. " (current)" or path
			end,
		}, function(choice)
			if choice then
				client:exec_cmd({ title = "Include context", command = "nml.includeContext", arguments = { uri, choice } }, { bufnr = bufnr })
			end
		end)
	end, bufnr)
end

return M
