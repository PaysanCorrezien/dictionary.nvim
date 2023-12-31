# dictionary.nvim -- Dictionary Manager for Neovim

🚧 WIP -- Not stable

Dictionary Manager is a Neovim plugin designed to enhance the spell checking and dictionary management experience. It integrates with `nvim-cmp` for spell suggestions and manages custom dictionaries for different languages, along with LTEX language server support.

## Features

- Manage multiple custom dictionaries.
- Spell suggestions with `nvim-cmp` integration.
- LTEX language server support for extended functionality.
- Easy addition and update of words in dictionaries.
- Configurable for various file types and use-cases.

_It should work on both windows and WSL_

## Prerequisites

- Neovim (0.9 or newer) , not tested in older version
- `nvim-cmp` plugin (for spell suggestions)
- LTEX language server (optional, for enhanced language support)
- ltex-extra.nvim

## 🪄 Installation

Install using your preferred Neovim package manager. For example, with `Lazy.nvim`:

```lua
        "paysancorrezien/dictionary.nvim"
		ft = "markdown",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			require("dictionary").setup({
				dictionary_paths = {
					home .. "/.config/nvim/dict/ltex.dictionary.fr.txt",
					home .. "/.config/nvim/dict/spell.utf-8.add",
				},
				override_zg = true,
				ltex_dictionary = true, -- if you are use ltex-ls extra and want to use zg to also update ltex-ls dictionary
				cmp = {
					enabled = true,
					custom_dict_path = local_ltex_ls,
					max_spell_suggestions = 10,
					filetypes = { "markdown", "tex" },
					priority = 20000,
					name = "mydictionary",
          source_label = "[Dict]",
          kind_icon = " "
				},
			})
		end,
	},
}
```

## 📖 Commands

```vim
:DictionaryAddWord - Add the current word to the spell and sync dictionaries.
:DictionaryConfigPrint - Print the current configuration.
:DictionaryUpdate - Update the custom dictionary.
:DictionaryPickLang - Pick a language and update LTEX-LS configuration
:DictionnaryUpdateLang fr - Update LTEX-LS configuration with the language `fr` or any others from [LTEX-ls](https://valentjn.github.io/ltex/supported-languages.html)
```

## Usage

To add a new word to your dictionaries, use the :DictionaryAddWord command while your cursor is over the word.

`:DictionaryUpdate` Open a new buffer with all merged dict, to edit them and sync

## 🎹 Example keymap configuration

I put all my note-taking binding's user `z` thanks to zettelkasten plugin,
so I use those :

```lua
vim.keymap.set("n", "<leader>zg", "<cmd>DictionaryAddWord <CR>", { desc = "Add word to dict" }) -- Add the current word to dictionary, if override_zg = true it does the same without leader
vim.keymap.set("n", "<leader>zL", "<cmd>DictionaryPickLang<CR>", { desc = "Change LSP Lang" })
vim.keymap.set("n", "<leader>gU", "<cmd>DictionaryUpdate <CR>", { desc = "Edit Dicts" })
vim.keymap.set("n", "<leader>zF", "<cmd>DictionaryUpdateLspLang fr<CR>", { desc = "Correct French" })
vim.keymap.set("n", "<leader>zE", "<cmd>DictionaryUpdateLspLang en<CR>", { desc = "Correct English" })
```

## License

This project is licensed under MIT License.
