-- `textDocument/codeRange`: the code of a document (its Lua, its code blocks) with its
-- language, highlighted with that language's syntax. Blocks get a background.
local util = require("nml-nvim.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("nml-code")

--- The syntax clusters included in each buffer, by language.
local included = {}

local function include(bufnr, language)
	included[bufnr] = included[bufnr] or {}
	if included[bufnr][language] == nil then
		local cluster = "nmlCode_" .. language:gsub("[^%w]", "_")
		local ok = pcall(vim.cmd, string.format("syntax include @%s syntax/%s.vim", cluster, language))
		-- A syntax file sets `b:current_syntax`, which stops the next one from loading.
		vim.b[bufnr].current_syntax = nil
		included[bufnr][language] = ok and cluster or false
	end
	return included[bufnr][language]
end

function M.setup(bufnr)
	local code = vim.api.nvim_get_hl(0, { name = "CursorLine" })
	vim.api.nvim_set_hl(0, "NML_Code", { bg = code.bg, default = true })
end

function M.clear(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
	vim.api.nvim_buf_call(bufnr, function()
		pcall(vim.cmd, "syntax clear nmlCode")
	end)
end

--- Whether a range is a block's code: it ends at the start of the line of the closing fence.
local function is_block(range)
	return range["end"].character == 0 and range["end"].line > range.start.line
end

--- A syntax region over a range, in the language's syntax.
local function region(bufnr, range, cluster)
	local function at(position)
		return string.format([[\%%%dl\%%%dc]], position.line + 1, util.byte_column(bufnr, position) + 1)
	end
	vim.cmd(string.format(
		[[syntax region nmlCode start=/%s/ end=/%s/me=s-1 keepend contains=@%s]],
		at(range.start), at(range["end"]), cluster
	))
end

function M.update(client, bufnr)
	util.request(client, "textDocument/codeRange", bufnr, function(result)
		M.clear(bufnr)
		vim.api.nvim_buf_call(bufnr, function()
			for _, code in ipairs(result or {}) do
				local range = code.range
				if code.language ~= "" then
					local cluster = include(bufnr, util.get_syntax_from_language(code.language))
					if cluster then
						region(bufnr, range, cluster)
					end
				end
				if is_block(range) then
					-- From the opening fence to the closing one.
					for line = math.max(range.start.line - 1, 0), range["end"].line do
						vim.api.nvim_buf_set_extmark(bufnr, M.ns, line, 0, {
							line_hl_group = "NML_Code",
						})
					end
				end
			end
		end)
	end)
end

return M
