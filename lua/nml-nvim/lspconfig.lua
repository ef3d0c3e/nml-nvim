local M = {}

function M.setup_lsp()
	local lspconfig = require('lspconfig')
	local configs = require('lspconfig.configs')

	if not configs.nmlls then
		configs.nmlls = {
			default_config = {
				cmd = { 'nmlls' },
				root_dir = lspconfig.util.root_pattern('.git'),
				filetypes = { 'nml' },
			},
		}
	end

	lspconfig.nmlls.setup {
		on_attach = function(client, bufnr)
			require("nml-nvim.code").setup(client, bufnr)
			require("nml-nvim.conceal").setup(client, bufnr)
			require("nml-nvim.style").setup(client, bufnr)
		end
	}
end

return M
