-- `textDocument/conceal`: markers to hide, and tokens drawn in their place (bullets,
-- checkboxes, quotes and callouts, code block headers after their fence). The cursor's line is shown as
-- written. Concealing needs `conceallevel` 2 in the window.
local util = require("nml-nvim.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("nml-conceal")

--- Per buffer: the conceals received, and the line shown as written.
local state = {}

local block_icons = {
	Quote = "",
	Note = "󰹕",
	Tip = "󰔤",
	Important = "",
	Warning = "",
	Caution = "󰒡",
	Todo = "󱦺",
}

local checkbox_icons = {
	Unchecked = "󰄱",
	Partial = "󰡖",
	Checked = "󰄵",
}

--- The header of a code block, after its fence: its language's icon and name.
local function code_icon(language)
	if language == "" then
		return nil
	end
	local icon = util.get_lang_icon(language)
	if icon == nil then
		return { " " .. language .. " ", "NML_Code_Lang" }
	end
	local group = "NML_Code_Lang_" .. util.get_syntax_from_language(language):gsub("[^%w]", "_")
	vim.api.nvim_set_hl(0, group, { fg = icon[2], bg = vim.api.nvim_get_hl(0, { name = "NML_Code_Lang", link = false }).bg })
	return { " " .. icon[1] .. " " .. language .. " ", group }
end

--- The extmark options of a token.
local function token_options(token, params)
	if token == "bullet" then
		return {
			conceal = params.numbered and "⦾" or "⦿",
			hl_group = string.format("NML_Bullet_%d", params.depth % 4),
		}
	elseif token == "checkbox" then
		return {
			conceal = "",
			virt_text = { { checkbox_icons[params.state] or "󰄱", "NML_Checkbox_" .. params.state } },
			virt_text_pos = "inline",
		}
	elseif token == "block" then
		return { conceal = "▌", hl_group = "NML_Block_" .. params.name }
	elseif token == "block_name" then
		local icon = block_icons[params.name] or ""
		return {
			conceal = "",
			virt_text = { { icon .. " " .. params.name, "NML_Block_" .. params.name } },
			virt_text_pos = "inline",
		}
	elseif token == "code" then
		-- The fences stay; what follows the opening one is drawn as a header.
		local text = { code_icon(params.language) }
		if params.name ~= "" then
			text[#text + 1] = { " ", "NML_Code" }
			text[#text + 1] = { " " .. params.name .. " ", "NML_Code_Name" }
		end
		return { conceal = "", virt_text = text, virt_text_pos = "inline" }
	end
end

--- Places the conceals of the buffer, except on `skip`, its cursor's line.
local function place(bufnr, skip)
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
	for _, conceal in ipairs(state[bufnr].conceals) do
		local range = conceal.range
		if range.start.line ~= skip then
			local options
			local target = conceal.concealText
			if target.text then
				options = { conceal = target.text }
			elseif target.token then
				options = token_options(target.token.token, target.token.params)
			end
			if options then
				options.end_row = range["end"].line
				options.end_col = util.byte_column(bufnr, range["end"])
				pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, range.start.line,
					util.byte_column(bufnr, range.start), options)
			end
		end
	end
	state[bufnr].shown = skip
end

local function cursor_line(bufnr)
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		return nil
	end
	return vim.api.nvim_win_get_cursor(win)[1] - 1
end

function M.setup(bufnr)
	local hl = function(name, value)
		value.default = true
		vim.api.nvim_set_hl(0, name, value)
	end
	hl("NML_Bullet_0", { fg = "#bf9a8a" })
	hl("NML_Bullet_1", { fg = "#ece2d0" })
	hl("NML_Bullet_2", { fg = "#d5b9b2" })
	hl("NML_Bullet_3", { fg = "#a26769" })
	hl("NML_Block_Quote", { fg = "#7dca70" })
	hl("NML_Block_Note", { fg = "#0cc4e3" })
	hl("NML_Block_Tip", { fg = "#c0ffcc" })
	hl("NML_Block_Important", { fg = "#b48ead" })
	hl("NML_Block_Warning", { fg = "#edba70" })
	hl("NML_Block_Caution", { fg = "#e54f4f" })
	hl("NML_Block_Todo", { fg = "#1ac8a4" })
	hl("NML_Code_Lang", { bg = "#2f2f34" })
	hl("NML_Code_Name", { bg = "#2f2f34", fg = "#c0ffcc" })
	hl("NML_Checkbox_Unchecked", { fg = "#4f4f4f" })
	hl("NML_Checkbox_Partial", { fg = "#af6f2f" })
	hl("NML_Checkbox_Checked", { fg = "#4f9f4f" })

	state[bufnr] = { conceals = {}, shown = nil }
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = vim.api.nvim_create_augroup("nml-nvim-conceal-" .. bufnr, { clear = true }),
		buffer = bufnr,
		callback = function()
			local line = cursor_line(bufnr)
			if state[bufnr] and line ~= state[bufnr].shown then
				place(bufnr, line)
			end
		end,
	})
end

function M.clear(bufnr)
	pcall(vim.api.nvim_del_augroup_by_name, "nml-nvim-conceal-" .. bufnr)
	state[bufnr] = nil
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
	end
end

function M.update(client, bufnr)
	util.request(client, "textDocument/conceal", bufnr, function(result)
		if not state[bufnr] then
			return
		end
		state[bufnr].conceals = result or {}
		place(bufnr, cursor_line(bufnr))
	end)
end

return M
