local M = {}

M.style_ns = vim.api.nvim_create_namespace("lsp_style")

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

    if style_info.style.group then
        hl_group = string.format("NML_Style_%s", style_info.style.group)
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
	-- Setup highlights
	vim.api.nvim_set_hl(0, "NML_Style_Bold", { link = "Bold" })
	vim.api.nvim_set_hl(0, "NML_Style_Italic", { link = "Italic" })
	vim.api.nvim_set_hl(0, "NML_Style_Underline", { link = "Underlined" })
	local bg_code = vim.api.nvim_get_hl(0, { name = "CursorLine" })
	vim.api.nvim_set_hl(0, "NML_Style_Code", { bg = bg_code.bg })

	-- Request style information from the LSP server on buffer changes
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
					M.update_style(client, bufnr)
				end)

			end)
		end
	})

	-- Trigger once
	vim.schedule(function()
		M.update_style(client, bufnr)
	end)
end

return M
