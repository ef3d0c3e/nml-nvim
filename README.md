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
	follow = true,         -- the live preview follows the cursor
	codelens = true,       -- the status of `:run` blocks, in code lenses
	fold = true,           -- fold sections, blocks and lists with the server's ranges
	picker = "auto",       -- `:NmlSymbols`: "snacks", "telescope", "select", or the first installed
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
  after their fence, which stays visible (with
  [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) icons when it is
  installed).
* `textDocument/style`: ranges to highlight, with `@markup.*` groups.
* `textDocument/codeRange`: code and its language. Code blocks are highlighted with that
  language's syntax and drawn on a background.

`:NmlIncludeContext` picks the file an included file is analysed in, among those that include
it.

## Live preview

`:NmlPreview` opens the current page in the browser, served by the language server from
memory: nothing is written. The page follows the buffer as you type, unsaved, and the rest of
the workspace as files are saved. With `follow`, the page scrolls to the block under the
cursor.

It runs the `nml.preview` command (the page's URI as argument; it answers the page's URL) and
sends `nml/cursor` notifications (`TextDocumentPositionParams`) when the cursor moves to
another line. Other editors can do the same.

## Outline

With `fold`, windows fold with the server's ranges (`foldmethod=expr`, `vim.lsp.foldexpr()`):
heading sections, blocks, lists and comments, open at first.

`:NmlPromote` and `:NmlDemote` change the level of every heading of the section at the cursor;
`:NmlMoveUp` and `:NmlMoveDown` swap it with the section of its level before or after. They are
also code actions on a heading's line.

## Tables

`vim.lsp.buf.format()` aligns the tables of the buffer, and only them: cells are padded to
their column, on the side the separator row aligns them to. `:NmlAlignTable` aligns the table
under the cursor. Tables with cell options (`[hspan=2]`) are left as written.

## Tangling

`:NmlTangle` writes the code blocks that have `tangle=path` to their files, as `nml tangle`
does.

## Symbols

`:NmlSymbols` picks among the workspace's files, what references can point to (headings,
figures, media, tables, listings, anchors) and its exported variables, with a preview, and goes
to the one picked. `:NmlSymbols references`, `variables` or `files` keeps one sort. It uses
[snacks.nvim](https://github.com/folke/snacks.nvim) or
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) when one is installed,
`vim.ui.select` otherwise; `picker` chooses.

They come from the server's `workspace/symbol`, so any picker's LSP workspace symbols list them
too, such as `Snacks.picker.lsp_workspace_symbols()`.

## Agenda

`:NmlAgenda` lists the tasks of the workspace (list items with a checkbox, headings with a
state such as `TODO`) by date: overdue, today, the next 7 days, later, and undated. A task's
date is the earliest of its `DEADLINE <…>`, `SCHEDULED <…>` and `<…>` timestamps.
`:NmlAgenda all` lists done tasks too. In the agenda, `<CR>` goes to a task, `t` toggles it
(a checkbox, or a heading's state), `r` refreshes and `q` closes.

It shows the server's `nml/agenda` request, and toggles with the `nml.toggleTask` command
(`[uri, line]`), also a code action on a checkbox's line.

## Running code

The server shows the status of each `:run` block in a code lens above it: completed, failed or
not run, and how long it took. `:NmlRun` runs the block under the cursor (or the last one above
it), and `:NmlRunAll` the blocks that have not completed; `vim.lsp.codelens.run()` runs the
lens on the cursor's line. `:NmlRunOutput`, or the `≡ Output` lens, shows everything the block
printed in a split (`q` closes it). Hovering the `:run` line shows the result. With `codelens = false`,
the lenses are not shown.

## Highlights

These are defined with `default = true`, so a colorscheme can override them:

* `NML_Bullet_0` to `NML_Bullet_3`: bullets, by depth.
* `NML_Checkbox_Unchecked`, `NML_Checkbox_Partial`, `NML_Checkbox_Checked`.
* `NML_Block_Quote`, `NML_Block_Note`, `NML_Block_Tip`, `NML_Block_Important`,
  `NML_Block_Warning`, `NML_Block_Caution`, `NML_Block_Todo`.
* `NML_Code`: the background of code blocks.
* `NML_Code_Lang`, `NML_Code_Name`: code block headers.
