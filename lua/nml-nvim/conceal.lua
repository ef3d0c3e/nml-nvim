local M = {}

-- TODO: Handle selections properly
M.conceal_ns = vim.api.nvim_create_namespace("lsp_conceal")
M.stored_marks = {}
M.last_hovered_line = nil

-- Store marks for a specific line
local function store_marks(bufnr, line)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, M.conceal_ns,
		{ line, 0 },
		{ line, -1 },
		{ details = true }
	)

	if not marks or #marks == 0 then return end

	M.stored_marks[bufnr] = M.stored_marks[bufnr] or {}
	M.stored_marks[bufnr][line] = vim.tbl_map(function(mark)
		return {
			col = mark[3],
			opts = {
				end_line = mark[4].end_line,
				end_col = mark[4].end_col,
				virt_text = mark[4].virt_text,
				virt_text_pos = mark[4].virt_text_pos,
				conceal = mark[4].conceal,
				hl_group = mark[4].hl_group,
			}
		}
	end, marks)
end

-- Restore marks for a specific line
local function restore_marks(bufnr, line)
	if not M.stored_marks[bufnr] or not M.stored_marks[bufnr][line] or line >= vim.api.nvim_buf_line_count(bufnr) then
		return
	end

	-- Clear and restore marks for the line
	vim.api.nvim_buf_clear_namespace(bufnr, M.conceal_ns, line, line + 1)
	for _, mark in ipairs(M.stored_marks[bufnr][line]) do
		vim.api.nvim_buf_set_extmark(bufnr, M.conceal_ns,
			line,
			mark.col,
			mark.opts
		)
	end

	-- Optionally clear stored marks after restoration
	M.stored_marks[bufnr][line] = nil
end

-- Clear conceals and handle line transitions
local function handle_hover(bufnr, current_line)
	-- Restore marks for the previously hovered line, if any
	if M.last_hovered_line and M.last_hovered_line ~= current_line then
		restore_marks(bufnr, M.last_hovered_line)
	end

	-- Store marks for the current line and clear conceals
	store_marks(bufnr, current_line)
	vim.api.nvim_buf_clear_namespace(bufnr, M.conceal_ns, current_line, current_line + 1)

	-- Update the last hovered line
	M.last_hovered_line = current_line
end

-- Process custom conceal tokens
function M.process_token(bufnr, range, token_type, token_params)
	if token_type == "bullet" then
		vim.api.nvim_buf_set_extmark(bufnr, M.conceal_ns, range.start.line, range.start.character, {
			end_line = range["end"].line,
			end_col = range["end"].character,
			conceal = (token_params.numbered and "⦾" or "⦿"),
			hl_group = string.format("NML_Bullet_%d", token_params.depth % 4)
		})
	elseif token_type == "block_name" then
		local icons = {
			["Warning"] = "",
			["Note"] = "󰹕",
			["Todo"] = "󱦺",
			["Caution"] = "󰒡",
			["Tip"] = "󰔤",
		}
		vim.api.nvim_buf_set_extmark(bufnr, M.conceal_ns, range.start.line, range.start.character, {
			end_line = range["end"].line,
			end_col = range["end"].character,
			virt_text = { { icons[token_params.name] .. " " .. token_params.name, string.format("NML_Block_%s", token_params.name) } },
			virt_text_pos = 'inline',
			conceal = "",
		})
	elseif token_type == "block" then
		vim.api.nvim_buf_set_extmark(bufnr, M.conceal_ns, range.start.line, range.start.character, {
			end_line = range["end"].line,
			end_col = range["end"].character,
			conceal = "▌",
			hl_group = string.format("NML_Block_%s", token_params.name)
		})
	end
end

function M.update_conceal(client, bufnr)
	-- Request conceal information from the LSP server
	local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }

	client.request("textDocument/conceal", params, function(err, result, ctx)
		if err then
			vim.notify("Error fetching conceal info: " .. vim.inspect(err), vim.log.levels.ERROR)
			return
		end

		-- Clear existing extmarks for styles
		M.stored_marks = {}
		vim.api.nvim_buf_clear_namespace(bufnr, M.conceal_ns, 0, -1)

		if not result or #result == 0 then
			return
		end

		-- Apply concealment
		for _, conceal in ipairs(result) do
			local range = conceal.range

			if conceal.concealText.text then
				-- Apply text conceal
				vim.api.nvim_buf_set_extmark(bufnr, M.conceal_ns, range.start.line, range.start.character, {
					end_line = range["end"].line,
					end_col = range["end"].character,
					conceal = conceal.concealText.text,
				})
			elseif conceal.concealText.token then
				-- Apply token conceal
				M.process_token(bufnr, range, conceal.concealText.token.token, conceal.concealText.token.params)
			end
		end

		-- Remove virtualtext on current line
		local cursor = vim.api.nvim_win_get_cursor(0)
		local current_line = cursor[1] - 1
		handle_hover(bufnr, current_line)

	end, bufnr)
end

-- Setup handler for the conceal extension provided by nmlls
function M.setup(client, bufnr)
	-- Setup highlights
	vim.api.nvim_set_hl(0, "NML_Bullet_0", { fg = '#bf9a8a' })
	vim.api.nvim_set_hl(0, "NML_Bullet_1", { fg = '#ece2d0' })
	vim.api.nvim_set_hl(0, "NML_Bullet_2", { fg = '#d5b9b2' })
	vim.api.nvim_set_hl(0, "NML_Bullet_3", { fg = '#a26769' })

	vim.api.nvim_set_hl(0, "NML_Block_Warning", { fg = '#EDBA70' })
	vim.api.nvim_set_hl(0, "NML_Block_Note", { fg = '#0CC4E3' })
	vim.api.nvim_set_hl(0, "NML_Block_Todo", { fg = '#1AC8A4' })
	vim.api.nvim_set_hl(0, "NML_Block_Caution", { fg = '#E54F4F' })
	vim.api.nvim_set_hl(0, "NML_Block_Tip", { fg = '#C0FFCC' })

	-- Request conceal information from the LSP server on buffer changes
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = vim.api.nvim_create_augroup("LspConcealGroup", { clear = true }),
		buffer = bufnr,
		callback = function()
			vim.schedule(function()
				M.update_conceal(client, bufnr)
			end)
		end
	})

	-- Clear conceals and handle restoration on hover
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold" }, {
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local cursor = vim.api.nvim_win_get_cursor(0)
			local current_line = cursor[1] - 1

			handle_hover(bufnr, current_line)
		end
	})

	-- Trigger once
	vim.schedule(function()
		require("nml-nvim.conceal").update_conceal(client, bufnr)
	end)
end

return M
