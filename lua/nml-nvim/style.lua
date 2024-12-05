local M = {}

M.style_ns = vim.api.nvim_create_namespace("lsp_style")
M.hl_cache = {}

--- Get or create a highlight group for a given color
-- @param color The color in #RRGGBB format
-- @return Highlight group name
local function get_or_create_hl_group(color, style)
    if M.hl_cache[color] then
        return M.hl_cache[color]
    end

    local hl_group = "LspStyle_" .. color:gsub("#", "")
	if style ~= nil then
		local group = { fg = color }
		if style == "bold" then
			group.bold = true
		end
		if style == "underlined" then
			group.bold = true
		end
		if style == "italic" then
			group.bold = true
		end

		vim.api.nvim_set_hl(0, hl_group, group)
	else
    	vim.api.nvim_set_hl(0, hl_group, { fg = color })
	end
    M.hl_cache[color] = hl_group
    return hl_group
end

--- Apply a style based on the received StyleInfo
-- @param bufnr The buffer number
-- @param style_info Table containing range and style information
local function apply_style(bufnr, style_info)
    local range = style_info.range
    local start_line = range.start.line
    local start_col = range.start.character
    local end_line = range["end"].line
    local end_col = range["end"].character

    local hl_group = nil

    if style_info.style.Color then
        -- Convert integer color to #RRGGBB
        local color = string.format("#%06x", style_info.style.Color)
        hl_group = get_or_create_hl_group(color)
    elseif style_info.style.Style then
        -- Use predefined styles (e.g., bold, italic)
        hl_group = style_info.style.Style
    elseif style_info.style.Full then
        local color = string.format("#%06x", style_info.style.Full.color)
        hl_group = get_or_create_hl_group(color, style_info.style.Full.style)
    end

    -- Apply extmark with highlight
    if hl_group then
        vim.api.nvim_buf_set_extmark(bufnr, M.style_ns, start_line, start_col, {
            end_line = end_line,
            end_col = end_col,
            hl_group = hl_group,
        })
    end
end

function M.update_style(client, bufnr)
    -- Request styles from the LSP server
    client.request("textDocument/style", { textDocument = { uri = vim.uri_from_bufnr(bufnr) } }, function(err, result)
        if err then
            vim.notify("Error fetching styles: " .. err.message, vim.log.levels.ERROR)
            return
        end

        -- Clear existing extmarks for styles
        vim.api.nvim_buf_clear_namespace(bufnr, M.style_ns, 0, -1)

        -- Apply all received styles
        for _, style_info in ipairs(result or {}) do
            apply_style(bufnr, style_info)
        end
    end, bufnr)
end

-- Setup handler for the style extension provided by nmlls
function M.setup(client, bufnr)
	-- Request style information from the LSP server on buffer changes
	vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
		group = vim.api.nvim_create_augroup("LspStyleGroup", {clear = true}),
		buffer = bufnr,
		callback = function()
			vim.schedule(function()
				require("nml-nvim.style").update_style(client, bufnr)
			end)
		end
	})

	-- Trigger once
	vim.schedule(function()
		require("nml-nvim.style").update_style(client, bufnr)
	end)
end

return M
