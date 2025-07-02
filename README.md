# nes.nvim

Next edit suggestion

https://github.com/user-attachments/assets/807042bc-1ecb-4a5f-8928-418293e7999b

**⚠️ Early Development Notice**

Please note that it is currently in a very early stage of development.
Features may be incomplete, bugs are likely to occur and breaking changes may occur frequently. Use with caution.

# Requirements

- `curl` in your `PATH`
- `github/copilot.vim` or `zbirenbaum/copilot.lua`: we don't depend on them directly, but you should sign in first
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

You can configure the plugin to use OpenRouter (an OpenAI-compatible proxy) by passing options to `setup`:

```lua
require('nes').setup({
  provider = 'openrouter',                  -- 'copilot' (default) or 'openrouter'
  api_key = 'YOUR_OPENROUTER_API_KEY',      -- required for openrouter
  base_url = 'https://api.openrouter.ai/v1', -- optional, default "https://api.openrouter.ai/v1"
  model = 'gpt-3.5-turbo',                  -- optional, default "gpt-3.5-turbo" for openrouter, "copilot-nes-v" for copilot
})
```

Leave `provider = 'copilot'` (or omit `provider`) to use GitHub Copilot.

# Usage

This plugin provide three functions:

- `get_suggestion(bufnr)`: to fetch the next edit suggestion
- `apply_suggestion(bufnr, opts)`: apply the fetched suggestion. option fields
  - `jump boolean`: auto jump to the end of the suggestion after apply
  - `trigger boolean`: auto trigger new suggestion
- `clear_suggestion(bufnr)`

Map these functions to your favorite keybindings. My keybindings are:

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

- `NesAdd`: highlight the added lines(default: link to 'DiffAdd')
- `NesDelete` highlight the deleted lines(default: link to 'DiffDelete')
- `NesApply` highlight the added lines after applied(default: link to 'DiffText'). You can disable this by passing opt `jump = {hl_timeout = 0}` to `apply_suggestion` function.

# TODO:

- multiple suggestions support
- auto trigger
