-- A picker of the workspace's symbols, from the server's `workspace/symbol`: its files, what
-- references can point to (headings, figures, tables, listings, anchors), and its exported
-- variables. Shown with snacks.nvim or telescope.nvim if one is installed, or `vim.ui.select`.
local M = {}

local kinds = vim.lsp.protocol.SymbolKind

--- NML's names of the protocol's kinds, as the server maps them.
local labels = {
	[kinds.File] = "file",
	[kinds.String] = "heading",
	[kinds.Object] = "figure",
	[kinds.Array] = "table",
	[kinds.Struct] = "listing",
	[kinds.Key] = "anchor",
	[kinds.Variable] = "variable",
}

--- The kinds each filter keeps.
M.filters = {
	all = function()
		return true
	end,
	files = function(label)
		return label == "file"
	end,
	references = function(label)
		return label ~= "file" and label ~= "variable"
	end,
	variables = function(label)
		return label == "variable"
	end,
}

--- The NML language server of a buffer.
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

---@class nml.SymbolItem
---@field text string
---@field label string
---@field file string
---@field pos integer[] Its line (from 1) and column (from 0).

--- Picks with snacks.nvim.
---@param title string
---@param items nml.SymbolItem[]
local function snacks(title, items)
	Snacks.picker.pick({
		title = title,
		items = items,
		format = function(item)
			return {
				{ string.format("%-9s", item.label), "Comment" },
				{ item.text },
			}
		end,
		preview = "file",
		confirm = "jump",
	})
end

--- Picks with telescope.nvim.
---@param title string
---@param items nml.SymbolItem[]
local function telescope(title, items)
	local conf = require("telescope.config").values
	require("telescope.pickers")
		.new({}, {
			prompt_title = title,
			finder = require("telescope.finders").new_table({
				results = items,
				entry_maker = function(item)
					return {
						value = item,
						display = string.format("%-9s %s", item.label, item.text),
						ordinal = item.label .. " " .. item.text,
						filename = item.file,
						lnum = item.pos[1],
						col = item.pos[2] + 1,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = conf.qflist_previewer({}),
		})
		:find()
end

--- Picks with `vim.ui.select`, which other pickers may provide.
---@param title string
---@param items nml.SymbolItem[]
local function select(title, items)
	vim.ui.select(items, {
		prompt = title,
		format_item = function(item)
			return string.format("%-9s %s", item.label, item.text)
		end,
	}, function(item)
		if item then
			vim.cmd.edit(vim.fn.fnameescape(item.file))
			vim.api.nvim_win_set_cursor(0, item.pos)
		end
	end)
end

--- The picker to use: the option, or the first installed.
---@return fun(title: string, items: nml.SymbolItem[])
local function picker()
	local choice = require("nml-nvim").options.picker or "auto"
	if choice == "snacks" or (choice == "auto" and rawget(_G, "Snacks") and Snacks.picker) then
		return snacks
	end
	if choice == "telescope" or (choice == "auto" and pcall(require, "telescope")) then
		return telescope
	end
	return select
end

--- The byte column of a position of the protocol in a file.
---@param file string
---@param position lsp.Position
---@param encoding string
---@return integer
local function byte_column(file, position, encoding)
	if position.character == 0 then
		return 0
	end
	local bufnr = vim.fn.bufnr(file)
	local line
	if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
		line = vim.api.nvim_buf_get_lines(bufnr, position.line, position.line + 1, false)[1]
	else
		line = vim.fn.readfile(file, "", position.line + 1)[position.line + 1]
	end
	local ok, col = pcall(vim.str_byteindex, line or "", encoding, position.character, false)
	return ok and col or position.character
end

--- The workspace's symbols, filtered, as picker items.
---@param result lsp.SymbolInformation[]
---@param keep fun(label: string): boolean
---@param encoding string
---@return nml.SymbolItem[]
function M.items(result, keep, encoding)
	local items = {}
	for _, symbol in ipairs(result or {}) do
		local label = labels[symbol.kind] or "symbol"
		if keep(label) then
			local file = vim.uri_to_fname(symbol.location.uri)
			local start = symbol.location.range.start
			local col = byte_column(file, start, encoding)
			items[#items + 1] = { text = symbol.name, label = label, file = file, pos = { start.line + 1, col } }
		end
	end
	return items
end

--- Picks a symbol of the workspace, and goes to it.
---@param bufnr integer
---@param filter? string `all` (default), `references`, `variables` or `files`.
function M.pick(bufnr, filter)
	filter = filter ~= "" and filter or "all"
	local keep = M.filters[filter]
	if not keep then
		vim.notify("Unknown filter `" .. filter .. "`: all, references, variables or files", vim.log.levels.ERROR)
		return
	end
	local client = nml_client(bufnr)
	if not client then
		vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
		return
	end
	client:request("workspace/symbol", { query = "" }, function(err, result)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
			return
		end
		local items = M.items(result, keep, client.offset_encoding)
		local title = filter == "all" and "NML symbols" or "NML " .. filter
		picker()(title, items)
	end, bufnr)
end

return M
