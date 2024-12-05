local M = {}

M.conceal_ns = vim.api.nvim_create_namespace("lsp_conceal")

-- Process custom conceal tokens
function M.process_token(bufnr, range, token_type, token_params)
	if token_type == "bullet" then
		vim.api.nvim_buf_set_extmark(bufnr, M.conceal_ns, range.start.line, range.start.character, {
			end_line = range["end"].line,
			end_col = range["end"].character,
			conceal = (token_params.numbered and "⦾" or "⦿"),
			hl_group = string.format("NML_Bullet_%d", token_params.depth % 4)
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
	end, bufnr)
end

-- Setup handler for the conceal extension provided by nmlls
function M.setup(client, bufnr)
	-- Setup highlights
	vim.api.nvim_set_hl(0, "NML_Bullet_0", { fg = '#bf9a8a' })
	vim.api.nvim_set_hl(0, "NML_Bullet_1", { fg = '#ece2d0' })
	vim.api.nvim_set_hl(0, "NML_Bullet_2", { fg = '#d5b9b2' })
	vim.api.nvim_set_hl(0, "NML_Bullet_3", { fg = '#a26769' })

	-- Request conceal information from the LSP server on buffer changes
	vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
		group = vim.api.nvim_create_augroup("LspConcealGroup", {clear = true}),
		buffer = bufnr,
		callback = function()
			vim.schedule(function()
				require("nml-nvim.conceal").update_conceal(client, bufnr)
			end)
		end
	})

	-- Trigger once
	vim.schedule(function()
		require("nml-nvim.conceal").update_conceal(client, bufnr)
	end)
end

return M
