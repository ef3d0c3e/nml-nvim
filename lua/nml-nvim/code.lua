local M = {}

local util = require("nml-nvim.util")

M.code_ns = vim.api.nvim_create_namespace("lsp_code")

local function try_language(language)
	local ok, _ = pcall(vim.cmd, string.format([[syntax include @%s syntax/%s.vim]], language, language))
	return ok
end

-- Define a syntax region and associate it with a language
function M.highlight_language_range(bufnr, range, language)
	local start_line = range.start.line
	local end_line = range["end"].line
	language = util.get_syntax_from_language(language)
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
-- @param bufnr The buffer number
function M.clear_highlights(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("syntax clear")
	end)
end

-- Creates a highlight rectangles over a line range
-- Also displays the language name as well as the block name if present
-- @param start_line Rectangle start line
-- @param end_line Rectangle end line
function M.highlight_rectangle(bufnr, start_line, end_line)
	-- Get the current window dimensions (width)
	local width = vim.api.nvim_win_get_width(0)

	-- Define the virtual text to use for highlighting (filling the entire width)
	local highlight_text = string.rep(" ", width) -- You can replace with any other character like "*" or "▏"

	-- Add virtual text to each line in the specified range
	for line = start_line, end_line do
		-- Apply to the line's text
		vim.api.nvim_buf_add_highlight(bufnr, M.code_ns, "NML_Code", line, 0, -1)

		-- Fill the 1 character gap
		local line_length = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]:len()
		vim.api.nvim_buf_set_extmark(bufnr, M.code_ns, line, line_length, {
			virt_text = { { " ", "NML_Code" } }, -- Highlight with a custom highlight group
			virt_text_pos = "overlay", -- Position the virtual text over the line (Region 2)
		})

		-- Apply the virtual text at the end of the line (positioned below the text)
		vim.api.nvim_buf_set_extmark(bufnr, M.code_ns, line, 0, {
			virt_text = { { highlight_text, "NML_Code" } }, -- Highlight with a custom highlight group
			virt_text_pos = "eol",             -- Position the virtual text at the end of the line
		})
	end
end

-- Retreive information from the lsp
-- @param client Ls client
-- @param bufnr Buffer number
function M.update_range(client, bufnr)
	-- Request codeRange from the LSP server
	client.request("textDocument/codeRange", { textDocument = { uri = vim.uri_from_bufnr(bufnr) } },
		function(err, result)
			if err then
				vim.notify("Error fetching styles: " .. err.message, vim.log.levels.ERROR)
				return
			end

			M.clear_highlights(bufnr)
			vim.api.nvim_buf_clear_namespace(bufnr, M.code_ns, 0, -1)

			-- Apply new highlights
			for _, code_range in ipairs(result) do
				M.highlight_language_range(bufnr, code_range.range, code_range.language)
				M.highlight_rectangle(bufnr, code_range.range.start.line - 1, code_range.range['end'].line)
			end
		end, bufnr)
end

-- Setup handler for the code range extension provided by nmlls
function M.setup(client, bufnr)
	local bg_code = vim.api.nvim_get_hl(0, { name = "CursorLine" })
	vim.api.nvim_set_hl(0, "NML_Code", { bg = bg_code.bg })

	-- Request code range information from the LSP server on buffer changes
	local debounce_timer = vim.loop.new_timer()
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "WinResized" }, {
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
