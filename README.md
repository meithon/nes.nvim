# nes.nvim

Next edit suggestion

# Requirements

- `curl` in your `PATH`
- `github/copilot.vim` or `zbirenbaum/copilot.lua`: we don't dependent them directly, should sigin first
- `nvim-lua/plenary.nvim`

# Installation

`lazy.nvim` for example:

```lua
{
    'Xuyuanp/nes.nvim',
    event = 'VeryLazy',
    dependencies = {
        'nvim-lua/plenary.nvim',
    },
    opts = {},
}

```

# Configuration

TODO

# Usage

This plugin provide three functions:

- `get_suggestion(bufnr)`: to fetch the next edit suggestion
- `apply_suggestion(bufnr, opts)`: apply the fetched suggestion. option fields
  - `jump boolean`: auto jump to the end of the suggestion after apply
  - `trigger boolean`: auto trigger new suggestion
- `clear_suggestion(bufnr)`

Map these functions for your favorite keybindings. My keybindings are:

```lua
-- lazy config
keys = {
    {
        '<A-i>',
        function()
            require('nes').get_suggestion()
        end,
        mode = 'i',
        desc = '[Nes] get suggestion',
    },
    {
        '<A-n>',
        function()
            require('nes').apply_suggestion(0, { jump = true, trigger = true })
        end,
        mode = 'i',
        desc = '[Nes] apply suggestion',
    },
},

```

# Highlight groups

- `NesAdd`: highlight the added lines(default: bg = fg of "@diff.plus")
- `NesDelete` highlight the deleted lines(default: bg = fg of "@diff.minus")
