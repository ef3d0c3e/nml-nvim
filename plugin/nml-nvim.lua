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
