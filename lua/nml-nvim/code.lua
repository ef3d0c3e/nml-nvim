local M = {}

M.code_ns = vim.api.nvim_create_namespace("lsp_code")

local function get_language(language)
	local map = {
		["C++"] = "cpp",
		["Plain Text"] = "text"
	}

	local lang = map[language]
	if lang == nil then
		lang = string.lower(language)
	end

	return lang
end

local function try_language(language)
	local ok, _ = pcall(vim.cmd, string.format([[syntax include @%s syntax/%s.vim]], language, language))
	return ok
end

-- Define a syntax region and associate it with a language
function M.highlight_language_range(bufnr, range, language)
	local start_line = range.start.line
	local end_line = range["end"].line
	language = get_language(language)
	-- Define a unique region name

	vim.api.nvim_buf_call(bufnr, function()
		-- Include the syntax rules for the target language
		if language == nil or language == '' or not try_language(language) then
			language = "text" -- Default fallback to plain text
			try_language(language) -- Ensure fallback succeeds
		end

		local region_name = "Embedded" .. language .. "_" .. start_line .. "_" .. end_line
		-- Define the syntax region for the language
		vim.cmd(string.format(
			[[syntax region %s start=/\%%%dl/ end=/\%%%dl/ contains=@%s]],
			region_name,
			start_line + 1,
			end_line + 1,
			language
		))
	end)
end

-- Clear all language-specific highlights
function M.clear_highlights(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("syntax clear")
	end)
end

function M.update_range(client, bufnr)
	-- Request codeRange from the LSP server
	client.request("textDocument/codeRange", { textDocument = { uri = vim.uri_from_bufnr(bufnr) } },
		function(err, result)
			if err then
				vim.notify("Error fetching styles: " .. err.message, vim.log.levels.ERROR)
				return
			end

			M.clear_highlights(bufnr)
			--vim.api.nvim_buf_clear_namespace(bufnr, M.code_ns, 0, -1)

			-- Apply new highlights
			for _, code_range in ipairs(result) do
				M.highlight_language_range(bufnr, code_range.range, code_range.language)
			end
		end, bufnr)
end

-- Setup handler for the code range extension provided by nmlls
function M.setup(client, bufnr)
	-- Request code range information from the LSP server on buffer changes
	local debounce_timer = vim.loop.new_timer()
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = vim.api.nvim_create_augroup("LspStyleGroup", { clear = true }),
		buffer = bufnr,
		callback = function()
			-- Throttle updates
			if debounce_timer:is_active() then
				debounce_timer:stop()
			end

			debounce_timer:start(500, 0, function()
				vim.schedule(function()
					M.update_range(client, bufnr)
				end)
			end)
		end
	})

	-- Trigger once
	M.update_range(client, bufnr)
end

return M
