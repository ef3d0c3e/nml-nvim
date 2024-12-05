local M = {}

function M.update_conceal(client, bufnr)
	-- Request conceal information from the LSP server
	local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }

	client.request("textDocument/conceal", params, function(err, result, ctx)
		if err then
			vim.notify("Error fetching conceal info: " .. vim.inspect(err), vim.log.levels.ERROR)
			return
		end

		if not result or #result == 0 then
			return
		end

		-- Apply concealment
		local ns_id = vim.api.nvim_create_namespace("conceal_namespace")
		for _, conceal in ipairs(result) do
			local range = conceal.range
			local conceal_text = ""
			local highlight_group = nil

			if conceal.conceal_text.Text then
				conceal_text = conceal.conceal_text.Text
			elseif conceal.conceal_text.Highlight then
				conceal_text = conceal.conceal_text.Highlight.text
				highlight_group = conceal.conceal_text.Highlight.highlight_group
			end

			-- Apply conceal with extmark
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, range.start.line, range.start.character, {
				end_line = range["end"].line,
				end_col = range["end"].character,
				conceal = conceal_text,
				hl_group = highlight_group, -- Highlight the concealed text
			})
		end
	end, bufnr)
end

-- Setup handler for the conceal extension provided by nmlls
function M.setup(client, bufnr)
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
