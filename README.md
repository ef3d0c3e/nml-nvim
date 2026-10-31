# nml-nvim

Neovim support for [NML](https://github.com/ef3d0c3e/nml): the `nml` filetype, and drawing
what the NML language server describes beyond the protocol. Requires Neovim 0.11.

The language server is `nml lsp`. It works with Neovim's own LSP client, with or without this
plugin. It gives diagnostics, completion, hover, definitions, references, inlay hints, code
actions and semantic tokens. In Lua code, it forwards these to
[LuaLS](https://github.com/LuaLS/lua-language-server) when that is installed.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
	"ef3d0c3e/nml-nvim",
	opts = {},
}
```

`setup()` registers the server as `nml` and enables it. Its options, with their defaults:

```lua
require("nml-nvim").setup({
	lsp = true,            -- register and enable the server
	cmd = { "nml", "lsp" }, -- the server's command
	luals = nil,           -- the path of LuaLS, or false; by default `NML_LUALS`, then the PATH
	conceal = true,        -- markers, bullets, checkboxes, quotes and code headers
	style = true,          -- emphasis, headings, links and code
	code = true,           -- code blocks in their language's syntax
})
```

Concealing needs `conceallevel` set to 2. The line under the cursor is always shown as written.

## Without `setup()`

The plugin ships `lsp/nml.lua`, so this is enough to start the server:

```lua
vim.lsp.enable("nml")
```

Change its configuration with `vim.lsp.config`:

```lua
vim.lsp.config("nml", {
	cmd = { "/path/to/nml", "lsp" },
	init_options = { luals = false },
})
```

The plugin adds its extras to any language server attached to an `nml` buffer, however the
server was registered.

## Without the plugin

The server needs nothing from the plugin:

```lua
vim.filetype.add({ extension = { nml = "nml" } })
vim.lsp.config("nml", {
	cmd = { "nml", "lsp" },
	filetypes = { "nml" },
	root_markers = { "nml.toml", ".git" },
})
vim.lsp.enable("nml")
```

## Extras

These use requests the server adds to the protocol:

* `textDocument/conceal`: markers to hide (`**`, `[[`, …), and tokens to draw in their place:
  list bullets, checkboxes, the bars and titles of quotes and callouts, and code block headers
  (with [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) icons when it is
  installed).
* `textDocument/style`: ranges to highlight, with `@markup.*` groups.
* `textDocument/codeRange`: code and its language. Code blocks are highlighted with that
  language's syntax and drawn on a background.

`:NmlIncludeContext` picks the file an included file is analysed in, among those that include
it.

## Highlights

These are defined with `default = true`, so a colorscheme can override them:

* `NML_Bullet_0` to `NML_Bullet_3`: bullets, by depth.
* `NML_Checkbox_Unchecked`, `NML_Checkbox_Partial`, `NML_Checkbox_Checked`.
* `NML_Block_Quote`, `NML_Block_Note`, `NML_Block_Tip`, `NML_Block_Important`,
  `NML_Block_Warning`, `NML_Block_Caution`, `NML_Block_Todo`.
* `NML_Code`: the background of code blocks.
* `NML_Code_Lang`, `NML_Code_Name`: code block headers.
