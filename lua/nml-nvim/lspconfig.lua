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

	local conceal = require("nml-nvim.conceal")
	lspconfig.nmlls.setup {
		on_attach = function(client, bufnr)
			conceal.setup(client, bufnr)
		end
	}
end

return M
