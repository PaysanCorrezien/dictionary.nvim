local SpellFile = {}

local Job = require("plenary.job")
local Path = require("plenary.path")

function SpellFile.download_spell_files(lang_code)
	local spell_dir = vim.fn.stdpath("data") .. "/site/spell/"
	local base_url = "https://ftp.nluug.nl/pub/vim/runtime/spell"

	-- Ensure the spell directory exists
	vim.fn.mkdir(spell_dir, "p")

	local download_command
	local download_args
	if jit.os == "Windows" then
		download_command = "powershell"
		download_args = function(url, dest_file)
			return {
				"-NoProfile",
				"-Command",
				string.format('Invoke-WebRequest -Uri "%s" -OutFile "%s"', url, dest_file),
			}
		end
	else
		download_command = "curl"
		download_args = function(url, dest_file)
			return { "-o", dest_file, url }
		end
	end

	local files_to_download = { lang_code .. ".utf-8.spl", lang_code .. ".utf-8.diff", "main.utf-8.spl" }

	for _, filename in ipairs(files_to_download) do
		local url = base_url .. "/" .. filename
		local dest_file = spell_dir .. filename

		vim.notify("Downloading " .. url)

		Job:new({
			command = download_command,
			args = download_args(url, dest_file),
			on_exit = function(j, return_val)
				if return_val == 0 then
					vim.notify("Downloaded " .. dest_file)
				else
					vim.notify("Failed to download " .. url, vim.log.levels.ERROR)
				end
			end,
		}):sync() -- or :start() for async
	end
end

function SpellFile.check_and_download_spell_files(lang_codes)
	local spell_dir = Path:new(vim.fn.stdpath("data"), "site", "spell")
	local files_needed = { ".utf-8.spl", ".utf-8.diff", "main.utf-8.spl" }

	for _, lang_code in ipairs(lang_codes) do
		local all_files_exist = true

		for _, ext in ipairs(files_needed) do
			local file_path = spell_dir:joinpath(lang_code .. ext)
			if not file_path:exists() then
				all_files_exist = false
				break
			end
		end

		if not all_files_exist then
			vim.notify("Some spell files missing for " .. lang_code .. ". Downloading...", vim.log.levels.INFO)
			SpellFile.download_spell_files(lang_code)
		else
			vim.notify("All spell files for " .. lang_code .. " are present.", vim.log.levels.INFO)
		end
	end
end
return SpellFile
