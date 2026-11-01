-- Loaded on startup: the `nml` filetype, and the extras of the NML language server for
-- `nml` buffers, however the server was registered.
if vim.g.loaded_nml_nvim then
	return
end
vim.g.loaded_nml_nvim = true

vim.filetype.add({ extension = { nml = "nml" } })

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("nml-nvim", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and vim.bo[args.buf].filetype == "nml" then
			require("nml-nvim").attach(client, args.buf)
		end
	end,
})

vim.api.nvim_create_user_command("NmlIncludeContext", function()
	require("nml-nvim.include").choose(vim.api.nvim_get_current_buf())
end, { desc = "Choose the file an included NML file is analysed in" })

vim.api.nvim_create_user_command("NmlPreview", function()
	require("nml-nvim.preview").open(vim.api.nvim_get_current_buf())
end, { desc = "Preview the NML page in the browser, live" })

vim.api.nvim_create_user_command("NmlRun", function()
	require("nml-nvim.run").run(vim.api.nvim_get_current_buf())
end, { desc = "Run the NML `:run` block under the cursor" })

vim.api.nvim_create_user_command("NmlRunAll", function()
	require("nml-nvim.run").run_all(vim.api.nvim_get_current_buf())
end, { desc = "Run the NML `:run` blocks that have not completed" })

vim.api.nvim_create_user_command("NmlRunOutput", function()
	require("nml-nvim.run").output(vim.api.nvim_get_current_buf())
end, { desc = "Show what the NML `:run` block under the cursor printed" })

vim.api.nvim_create_user_command("NmlSymbols", function(args)
	require("nml-nvim.symbols").pick(vim.api.nvim_get_current_buf(), args.args)
end, {
	nargs = "?",
	complete = function()
		return { "all", "references", "variables", "files" }
	end,
	desc = "Pick a file, reference target or exported variable of the NML workspace",
})

vim.api.nvim_create_user_command("NmlPromote", function()
	require("nml-nvim.outline").run(vim.api.nvim_get_current_buf(), "nml.promote")
end, { desc = "Promote the NML section at the cursor: its headings go up a level" })

vim.api.nvim_create_user_command("NmlDemote", function()
	require("nml-nvim.outline").run(vim.api.nvim_get_current_buf(), "nml.demote")
end, { desc = "Demote the NML section at the cursor: its headings go down a level" })

vim.api.nvim_create_user_command("NmlMoveUp", function()
	require("nml-nvim.outline").run(vim.api.nvim_get_current_buf(), "nml.moveUp")
end, { desc = "Move the NML section at the cursor above the one before" })

vim.api.nvim_create_user_command("NmlMoveDown", function()
	require("nml-nvim.outline").run(vim.api.nvim_get_current_buf(), "nml.moveDown")
end, { desc = "Move the NML section at the cursor below the one after" })

vim.api.nvim_create_user_command("NmlAlignTable", function()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	vim.lsp.buf.format({
		name = "nml",
		range = { start = { line, 0 }, ["end"] = { line, 0 } },
	})
end, { desc = "Align the NML table under the cursor" })

vim.api.nvim_create_user_command("NmlTangle", function()
	local bufnr = vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local provider = client.server_capabilities.executeCommandProvider
		if provider and vim.tbl_contains(provider.commands or {}, "nml.tangle") then
			client:exec_cmd({ title = "Tangle", command = "nml.tangle" }, { bufnr = bufnr }, function(err)
				if err then
					vim.notify(err.message, vim.log.levels.ERROR)
				end
			end)
			return
		end
	end
	vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
end, { desc = "Write the NML code blocks with `tangle=path` to their files" })

vim.api.nvim_create_user_command("NmlAgenda", function(args)
	require("nml-nvim.agenda").open(args.args == "all")
end, {
	nargs = "?",
	complete = function()
		return { "all" }
	end,
	desc = "The agenda of the NML workspace: its tasks by date (`all`: done ones too)",
})
