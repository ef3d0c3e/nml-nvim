local ft = require("nml-nvim.ft")
local lspconfig = require("nml-nvim.lspconfig")

local M = {}

function M.setup()
	ft.setup_filetype()
	lspconfig.setup_lsp()
end

return M
