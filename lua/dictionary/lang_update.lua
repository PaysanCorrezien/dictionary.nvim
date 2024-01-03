local LangUpdate = {}

-- https://valentjn.github.io/ltex/supported-languages.html
local languages = {
	"ar",
	"ast-ES",
	"be-BY",
	"br-FR",
	"ca-ES",
	"ca-ES-valencia",
	"zh-CN",
	"da-DK",
	"nl",
	"nl-BE",
	"en",
	"en-AU",
	"en-CA",
	"en-GB",
	"en-NZ",
	"en-ZA",
	"en-US",
	"eo",
	"fr",
	"gl-ES",
	"de",
	"de-AT",
	"de-DE",
	"de-CH",
	"el-GR",
	"ga-IE",
	"it",
	"ja-JP",
	"km-KH",
	"fa",
	"pl-PL",
	"pt",
	"pt-AO",
	"pt-BR",
	"pt-MZ",
	"pt-PT",
	"ro-RO",
	"ru-RU",
	"de-DE-x-simple-language",
	"sk-SK",
	"sl-SI",
	"es",
	"es-AR",
	"sv",
	"tl-PH",
	"ta-IN",
	"uk-UA",
}

--  credit : https://github.com/valentjn/ltex-ls/issues/256

--- Function to change the language of the LTeX Language Server
--- @param language string
--- @return nil
function LangUpdate.changeLanguage(language)
	local bufnr = vim.api.nvim_get_current_buf()
	local client = vim.lsp.get_active_clients({ bufnr = bufnr, name = "ltex" })

	if #client == 0 then
		vim.notify("No ltex client attached")
	else
		client = client[1]
		client.config.settings = {
			ltex = {
				language = language,
			},
		}
		client.notify("workspace/didChangeConfiguration", client.config.settings)
		vim.notify("Language changed to " .. language)
	end
end

function LangUpdate.pick_lang()
	vim.ui.select(languages, {
		prompt = "Select a Language:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			require("dictionary.lang_update").changeLanguage(choice)
		end
	end)
end

return LangUpdate
