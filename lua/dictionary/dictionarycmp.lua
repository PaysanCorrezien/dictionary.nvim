local cmp = require("cmp")

local DictionaryCMP = {}

function DictionaryCMP.new(config)
    local source = {
        config = config,
        custom_dict_path = config.custom_dict_path,
        max_spell_suggestions = config.max_spell_suggestions or 10,
        keyword_pattern = config.keyword_pattern or ".",
        kind_icon = config.kind_icon or cmp.lsp.CompletionItemKind.Text,
    }
    setmetatable(source, { __index = DictionaryCMP })
    return source
end

function DictionaryCMP:get_metadata()
    return {
        priority = self.config.priority,
        menu = self.config.source_label,
        debounce = 0,
        name = self.config.name,
    }
end


function DictionaryCMP:is_available()
	local is_available = vim.tbl_contains(self.config.filetypes, vim.bo.filetype)
	return is_available
end

function DictionaryCMP:get_custom_suggestions(prefix)
	local suggestions = {}
	if self.custom_dict_path then
		for line in io.lines(self.custom_dict_path) do
			if string.find(line, prefix) == 1 then
				-- print("Matching word from custom dict: ", line)
        table.insert(suggestions, {
        label = line,
        kind = self.config.kind_icon,
    })
			end
		end
	end
	return suggestions
end

function DictionaryCMP:get_keyword_pattern()
  return self.config.keyword_pattern
end

function DictionaryCMP:generate_candidates(input, option)
	local items = {}
	local customDictItems = {}
	local vimSpellItems = {}
	local offset, loglen
	local seenLabels = {} -- Table to keep track of labels already added
	local max_spell_suggestions = option.max_spell_suggestions or 10 -- Default to 10 suggestions if not specified

	-- Custom dictionary suggestions
	if self.custom_dict_path then
		for line in io.lines(self.custom_dict_path) do
			if string.find(line, input) == 1 and not seenLabels[line] then
				customDictItems[#customDictItems + 1] = {
					label = line,
					kind = self.config.kind_icon,
					sortText = "1" .. line,
				}
				seenLabels[line] = true -- Mark this label as seen
			end
		end
	end

	-- Vim spell suggestions
	local entries = vim.fn.spellsuggest(input, max_spell_suggestions)
	if vim.tbl_isempty(vim.spell.check(input)) then
		-- Correctly spelled word takes the highest priority
		offset = 1
		loglen = math.ceil(math.log10(#entries + 1))
		local label = input
		if not seenLabels[label] then
			items[#items + 1] = {
				label = label,
				filterText = label,
				sortText = string.format("%0" .. loglen .. "d", offset),
				preselect = true,
			}
			seenLabels[label] = true -- Mark this label as seen
		end
	else
		offset = 0
		loglen = math.ceil(math.log10(#entries))
	end

	-- Add custom dictionary items right after the correctly spelled word
	for _, item in ipairs(customDictItems) do
		items[#items + 1] = item
	end
    -- Then add other Vim spell suggestions
    for k, v in ipairs(entries) do
        if not seenLabels[v] then
            local spellItem = {
                label = v,
                filterText = option.keep_all_entries and input or v,
                sortText = string.format("2%0" .. loglen .. "d", k + offset),
            }
            table.insert(vimSpellItems, spellItem)
            seenLabels[v] = true -- Mark this label as seen
        end
    end
    -- Combine lists
    local combinedItems = {}
    for _, item in ipairs(customDictItems) do
        table.insert(combinedItems, item)
    end
    for _, item in ipairs(vimSpellItems) do
        table.insert(combinedItems, item)
    end
    return combinedItems
end

function DictionaryCMP:complete(params, callback)
	local input = string.match(params.context.cursor_before_line, "[^%s%p]*$")
	local option = {
		keep_all_entries = self.config.keep_all_entries or false,
		enable_in_context = self.config.enable_in_context or function()
			return true
		end,
	}

	if option.enable_in_context(params) then
		local candidates = self:generate_candidates(input, option)
		callback({ items = candidates, isIncomplete = true })
	else
		callback({ items = {}, isIncomplete = true })
	end
end

return DictionaryCMP
