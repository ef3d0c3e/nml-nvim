-- The NML language server, for Neovim's own LSP client (0.11+): `vim.lsp.enable("nml")`.
-- Options can be changed with `vim.lsp.config("nml", { ... })`.
---@type vim.lsp.Config
return {
	cmd = { "nml", "lsp" },
	filetypes = { "nml" },
	root_markers = { "nml.toml", ".git" },
	-- `luals`: the path of LuaLS, or `false` to go without it. By default, the server looks
	-- for `lua-language-server` in `NML_LUALS`, then on the `PATH`.
	init_options = {},
}
