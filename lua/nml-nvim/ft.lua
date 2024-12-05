local M = {}

-- Defines the `*.nml` filetype
function M.setup_filetype()
  vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = "*.nml",
    callback = function()
      vim.bo.filetype = "nml"
    end,
  })
end

return M
