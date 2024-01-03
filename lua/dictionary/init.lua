local Path = require("plenary.path")
local cmp = require("cmp")
local spellfile = require("dictionary.spellfile")

local DictionaryManager = {}

-- TODO: swapping language function with reload both spell and dict
-- TODO: vrap lot of features of :help spell mkspell/ combine dictionnary / download them
-- TODO: Show list of binding related to spell suggestion
-- TODO: telescope / quicklist with LTEX + Spell correction
-- TODO: Handle LTEX-LS setup and configuration too ? and options
-- TODO: proper log management
-- Default configuration
function DictionaryManager.get_spellfile()
	return vim.opt.spellfile:get()
end

DictionaryManager.config = {
	dictionary_paths = {}, -- Array of dictionary file paths
	override_zg = false,
	ltex_dictionary = false, -- New option
	spelllang = vim.o.spelllang, -- New option
	cmp = {
		enabled = false,
		custom_dict_path = "",
		max_spell_suggestions = 10,
		filetypes = { "markdown", "md" }, -- Default filetypes
		priority = 20000,
		name = "dictionary",
		source_label = "[Dict]",
		keyword_pattern = ".", -- Any to allow all suggestion from spellsuggest()
		-- Others option from spell-cmp :
		--  keyword_pattern = "[[\K\+]]"
		kind_icon = cmp.lsp.CompletionItemKind.Text, -- Icon for suggestions
	},
}

--- Checks the prerequisites for the DictionaryManager class.
--- @param config table The configuration table.
--- @return boolean Returns true if all prerequisites are met, otherwise returns false.
function DictionaryManager.check_prerequisites(config)
	local function notify_error(message)
		vim.notify("DictionaryManager Error: " .. message, vim.log.levels.ERROR)
	end

	-- Check if spell option is enabled
	if not vim.wo.spell then
		notify_error("Vim spell option is not enabled.")
		return false
	end

	-- Check if spelllang is set
	if vim.o.spelllang == "" then
		notify_error("Vim 'spelllang' is not set.")
		return false
	end

	-- Check if custom_dict_path is provided and exists
	if config.cmp and config.cmp.custom_dict_path then
		local dict_path = config.cmp.custom_dict_path
		if not vim.fn.filereadable(dict_path) then
			notify_error("Custom dictionary path does not exist or is not readable: " .. dict_path)
			return false
		end
	else
		notify_error("'custom_dict_path' is not provided in config.")
		return false
	end

	-- Check if cmp is enabled and working
	if config.cmp and config.cmp.enabled then
		local status, _ = pcall(require, "cmp")
		if not status then
			notify_error("'nvim-cmp' is not installed or not working correctly.")
			return false
		end
	end
	-- Check if ltex-ls LSP is installed and working (when ltex_dictionary is enabled)
	-- TODO : use the getlsp function instead ?
	-- BUG: because lsp is not registered before plugin load
	-- if config.ltex_dictionary then
	-- 	local current_lang = DictionaryManager.get_current_lsp_language()
	-- 	if not current_lang then
	-- 		error("DictionaryManager Error: 'ltex-ls' LSP is not installed or not active in the current buffer.")
	-- 		return false
	-- 	end
	-- end

	-- Check if dictionary_paths contains at least two entries
	if #config.dictionary_paths < 2 then
		error("DictionaryManager Error: 'dictionary_paths' must contain at least two entries.")
		return false
	end

	return true
end

-- Print current configuration
function DictionaryManager.conf()
	print("Current DictionaryManager Configuration:")
	for k, v in pairs(DictionaryManager.config) do
		if type(v) == "table" then
			print(k .. ": " .. table.concat(v, ", "))
		else
			print(k .. ": " .. tostring(v))
		end
	end
	-- cmp part
	for k, v in pairs(DictionaryManager.config.cmp) do
		if type(v) == "table" then
			print(k .. ": " .. table.concat(v, ", "))
		else
			print(k .. ": " .. tostring(v))
		end
	end

	-- Check and print the current language set by LSP
	-- TODO : make this conditional
	local current_lsp_language = DictionaryManager.get_current_lsp_language()
	if current_lsp_language then
		print("Current LSP Language: " .. current_lsp_language)
	else
		print("Current LSP Language: Not available or not set")
	end
end

-- Used to get ltex-ls language to call ltex-extra add dictionary with good param ( to manage multiples langs)
function DictionaryManager.get_current_lsp_language()
	local clients = vim.lsp.get_active_clients()
	for _, client in pairs(clients) do
		if client.name == "ltex" then
			local lang = client.config.settings.ltex.language
			if lang then
				return lang
			end
		end
	end
	return nil
end

function DictionaryManager.get_dictionaries_lines()
	local master_lines = {}
	for _, dictionary_path in ipairs(DictionaryManager.config.dictionary_paths) do
		-- print("Reading dictionary path:", dictionary_path) -- Debug print
		local path = vim.loop.fs_open(dictionary_path, "r", 438) -- 438 = 0666 in octal
		if path then
			local stat = vim.loop.fs_fstat(path)
			if stat then
				local data = vim.loop.fs_read(path, stat.size)
				vim.loop.fs_close(path)
				for line in data:gmatch("[^\r\n]+") do
					master_lines[line] = true
				end
			else
				print("Failed to get file stats for:", dictionary_path) -- Debug print
			end
		else
			print("Failed to open dictionary path:", dictionary_path) -- Debug print
		end
	end
	-- NOTE: USEFULL FOR DEBUG
	-- print("Finished processing dictionaries.") -- Debug print
	-- for k, v in pairs(master_lines) do
	-- 	if type(v) == "table" then
	-- 		print(k .. ": " .. table.concat(v, ", "))
	-- 	else
	-- 		print(k .. ": " .. tostring(v))
	-- 	end
	-- end
	return master_lines
end

function DictionaryManager.write_dictionaries(lines)
	-- Determine line separator based on operating system
	local line_separator = (vim.loop.os_uname().sysname == "Windows") and "\r\n" or "\n"

	local line_list = {}
	for line, _ in pairs(lines) do
		table.insert(line_list, line)
	end
	local content_str = table.concat(line_list, line_separator)

	-- print("Content length to write:", #content_str) -- Debugging content length
	-- Ensure the content ends with a newline
	-- Attempt to correct bug with update function that miss a newline
	-- BUG: because of this it print that i deleted and added the last line each time
	if not content_str:match(line_separator .. "$") then
		content_str = content_str .. line_separator
	end

	for _, dictionary_path in ipairs(DictionaryManager.config.dictionary_paths) do
		-- print("Attempting to write to:", dictionary_path) -- Debug print

		local path, open_err = vim.loop.fs_open(dictionary_path, "w", 438)
		if not path then
			print("Error opening file:", dictionary_path, "Error:", open_err)
			goto continue
		end

		local bytes_written, write_err = vim.loop.fs_write(path, content_str)
		if not bytes_written then
			print("Error writing to file:", dictionary_path, "Error:", write_err)
		else
			-- print("Bytes written:", bytes_written, "to", dictionary_path) -- Debug print
		end

		local close_success, close_err = vim.loop.fs_close(path)
		if not close_success then
			print("Error closing file:", dictionary_path, "Error:", close_err)
		end

		::continue::
	end
end

function DictionaryManager.append_to_dictionaries(word)
	local lines = DictionaryManager.get_dictionaries_lines()
	lines[word] = true
	DictionaryManager.write_dictionaries(lines)
end

function DictionaryManager.update_custom_dictionary()
	local lines = DictionaryManager.get_dictionaries_lines()
	local buf = vim.api.nvim_create_buf(false, false) -- Create a normal, empty buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_keys(lines))

	-- Assign a dummy filename to satisfy Neovim's requirement
	local dummy_filename = vim.fn.tempname() -- Generates a temporary filename
	vim.api.nvim_buf_set_name(buf, dummy_filename)

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "modifiable", true)

	-- Set autocommands to handle buffer write
	vim.cmd(string.format(
		[[
        augroup UpdateDictionary
            autocmd!
            autocmd BufWritePre <buffer=%s> lua require('dictionary').handle_buffer_write()
            autocmd BufWritePost <buffer=%s> set nomodified | lua vim.api.nvim_buf_set_name(0, '')
        augroup END
    ]],
		buf,
		buf
	))

	-- Switch to the new buffer
	vim.api.nvim_set_current_buf(buf)
end

-- TODO : prevent temp file usage
function DictionaryManager.handle_buffer_write()
	local bufnr = vim.api.nvim_get_current_buf()
	local dummy_filename = vim.api.nvim_buf_get_name(bufnr)
	local original_lines = DictionaryManager.get_dictionaries_lines()
	local updated_lines = {}
	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	-- print("Buffer lines:", vim.inspect(buf_lines))
	-- Bug of newline missing that prevent adding word correctly after edit inside the buffer
	local last_line = buf_lines[#buf_lines]
	if last_line and not last_line:match("\n$") then
		buf_lines[#buf_lines] = last_line .. "\n"
	end

	local bufnr = vim.api.nvim_get_current_buf()
	-- Initialize updated_lines with buffer lines marked as "added"
	for _, line in ipairs(buf_lines) do
		updated_lines[line] = "added"
	end

	-- Determine the status of each line
	local removed_lines = {}
	for line in pairs(original_lines) do
		if updated_lines[line] then
			-- Line is present in both, mark as "kept"
			updated_lines[line] = "kept"
		else
			-- Line is in original but not in updated, mark as "removed"
			removed_lines[line] = "removed"
		end
	end

	-- Prepare to print results
	local added, kept, removed = {}, {}, {}
	for line, status in pairs(updated_lines) do
		if status == "added" then
			table.insert(added, line)
		elseif status == "kept" then
			table.insert(kept, line)
		end
	end
	for line, _ in pairs(removed_lines) do
		table.insert(removed, line)
	end

	-- Print added, kept, and removed words
	local content = ""
	if #added > 0 then
		content = content .. "Added words: " .. table.concat(added, ", ") .. "\n"
	end
	-- if #kept > 0 then
	-- 	content = content .. "Kept words: " .. table.concat(kept, ", ") .. "\n"
	-- end
	if #removed > 0 then
		content = content .. "Removed words: " .. table.concat(removed, ", ")
	end

	-- Write updated lines back to all dictionaries
	DictionaryManager.write_dictionaries(updated_lines)

	--TODO : include check if write_dictionaries success
	if content ~= "" then
		vim.notify(content, vim.log.levels.INFO)
	end

	-- Remove the temporary file if it exists
	if dummy_filename and dummy_filename ~= "" then
		os.remove(dummy_filename)
	end

	-- Defer the buffer deletion to ensure the write operation completes
	vim.defer_fn(function()
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end, 0)
end

-- function DictionaryManager.update_dictionaries()
-- 	local original_lines = DictionaryManager.get_dictionaries_lines()
-- 	local updated_lines = {}
-- 	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

-- 	-- Populate updated_lines table with lines from the buffer
-- 	for _, line in ipairs(buf_lines) do
-- 		updated_lines[line] = true
-- 	end

-- 	-- Write updated lines back to all dictionaries
-- 	DictionaryManager.write_dictionaries(vim.tbl_keys(updated_lines))
-- end

-- Public API
function DictionaryManager.setup(user_config)
	-- Merging user_config with the default config
	DictionaryManager.config = vim.tbl_deep_extend("force", DictionaryManager.config, user_config or {})

	if not DictionaryManager.check_prerequisites(DictionaryManager.config) then
		return -- Stop if prerequisites are not met
	end

	if DictionaryManager.config.cmp and DictionaryManager.config.cmp.enabled then
		local status, DictionaryCMP = pcall(require, "dictionary.dictionarycmp")
		if not status then
			print("Error loading dictionarycmp module: " .. DictionaryCMP) -- DictionaryCMP contains error message
			return
		end

		-- print("CMP Config: ", vim.inspect(DictionaryManager.config.cmp))
		local status, cmp_source = pcall(DictionaryCMP.new, DictionaryManager.config.cmp)
		if not status then
			print("Error initializing DictionaryCMP: " .. cmp_source) -- cmp_source contains error message
			return
		end

		local status, result = pcall(cmp.register_source, "dictionary", cmp_source)
		if not status then
			print("Error registering CMP source: " .. result) -- result contains error message
		else
			-- print("CMP source registered successfully.")
		end
	end
	-- Ensure at least one dictionary path is set
	if #DictionaryManager.config.dictionary_paths == 0 then
		error("DictionaryManager: At least one dictionary path must be set.")
		return
	end
	-- Register the Vim command
	vim.cmd("command! DictionaryAddWord lua require('dictionary').add_word_to_spell_and_sync()")
	vim.cmd("command! DictionaryConfigPrint lua require('dictionary').conf()")
	vim.cmd("command! DictionaryUpdate lua require('dictionary').update_custom_dictionary()")
	-- init.lua

	vim.cmd([[
command! -nargs=* DictionaryAddSpellFile 
    \ lua require('dictionary.spellfile').check_and_download_spell_files({<f-args>})
]])

	if DictionaryManager.config.override_zg then
		vim.api.nvim_set_keymap(
			"n",
			"zg",
			':lua require("dictionary").add_word_to_spell_and_sync()<CR>',
			{ noremap = true, silent = true }
		)
	end
end

local function update_spell_dictionary()
	-- Add word to Neovim's spell dictionary
	vim.cmd("silent! normal! zg")
end

local function update_ltex_dictionary(word, lang)
	require("ltex_extra.commands-lsp").addToDictionary({
		arguments = { { words = { [lang] = { word } } } },
	})
end

-- updating both individualy + rewriting all is redondant but needed because they dont update buffer on file change, reloading complete lsp is too slow
-- TODO: maybe reload lsp dict function can make this way better ?
function DictionaryManager.add_word_to_spell_and_sync()
	local word = vim.fn.expand("<cword>")
	update_spell_dictionary() -- Update Neovim's spell dictionary

	if DictionaryManager.config.ltex_dictionary then
		local lang = DictionaryManager.get_current_lsp_language()
		update_ltex_dictionary(word, lang) -- Update LTeX dictionary
	end

	local all_lines = DictionaryManager.get_dictionaries_lines()

	-- DictionaryManager.write_dictionaries(all_lines)
	vim.notify('Added "' .. word .. '" to dictionaries', vim.log.levels.INFO)
end

return DictionaryManager
