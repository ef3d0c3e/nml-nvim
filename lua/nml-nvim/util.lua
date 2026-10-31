local M = {}

-- Maps NML language to nvim syntax group
-- @param language String
function M.get_syntax_from_language(language)
	local map = {
		["C++"] = "cpp",
		["C#"] = "cs",
		["Objective-C"] = "objc",
		["Objective-C++"] = "objcpp",
		["Plain Text"] = "text"
	}

	local lang = map[language]
	if lang == nil then
		lang = string.lower(language)
	end

	return lang
end

-- Gets the icon for a language as well as the highlight group
-- @param name String : The language's name
function M.get_lang_icon(language)
	local map = {
		["C++"] = "cpp",
		["C#"] = "cs",
		["Objective-C"] = "objc",
		["Objective-C++"] = "objcpp",
		["Plain Text"] = "txt"
	}

	local ok, icon, color = pcall(function()
		local lang = map[language]
		if lang == nil then
			lang = string.lower(language)
		end
		return require'nvim-web-devicons'.get_icon_color("file." .. lang, lang)
	end)

	if not ok or icon == nil then
		return nil
	end
	return {icon, color}
end

--- Calls `callback` after the buffer's changes were sent to the server, at most once in
--- `delay` milliseconds (the server has analysed them by the time it answers).
---@param client vim.lsp.Client
---@param bufnr integer
---@param callback fun()
---@param delay? integer
function M.on_change(client, bufnr, callback, delay)
	local timer = assert(vim.uv.new_timer())
	local group = vim.api.nvim_create_augroup("nml-nvim-" .. bufnr, { clear = true })
	vim.api.nvim_create_autocmd("LspNotify", {
		group = group,
		buffer = bufnr,
		callback = function(args)
			if args.data.client_id ~= client.id or args.data.method ~= "textDocument/didChange" then
				return
			end
			timer:stop()
			timer:start(delay or 200, 0, vim.schedule_wrap(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					callback()
				end
			end))
		end,
	})
	vim.api.nvim_create_autocmd({ "LspDetach", "BufUnload" }, {
		group = group,
		buffer = bufnr,
		callback = function(args)
			if args.event == "LspDetach" and args.data.client_id ~= client.id then
				return
			end
			timer:stop()
			timer:close()
			vim.api.nvim_del_augroup_by_id(group)
			require("nml-nvim").detach(client.id, bufnr)
		end,
	})
end

--- Sends a request about a buffer, and calls `handler` with its result if it succeeds.
---@param client vim.lsp.Client
---@param method string
---@param bufnr integer
---@param handler fun(result: any)
function M.request(client, method, bufnr, handler)
	local params = { textDocument = { uri = vim.uri_from_bufnr(bufnr) } }
	client:request(method, params, function(err, result)
		if err then
			vim.notify(string.format("%s: %s", method, err.message), vim.log.levels.WARN)
			return
		end
		if vim.api.nvim_buf_is_valid(bufnr) then
			handler(result)
		end
	end, bufnr)
end

--- The byte column of a position the server sent (in UTF-16 units).
---@param bufnr integer
---@param position lsp.Position
---@return integer
function M.byte_column(bufnr, position)
	local line = vim.api.nvim_buf_get_lines(bufnr, position.line, position.line + 1, false)[1]
	if not line then
		return 0
	end
	local ok, column = pcall(vim.str_byteindex, line, "utf-16", position.character, false)
	return ok and column or #line
end

return M
