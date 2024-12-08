local M = {}

-- Maps NML language to nvim syntax group
-- @param language String
function M.get_syntax_from_language(language)
	local map = {
		["C++"] = "cpp",
		["C#"] = "cs",
		["Objective-C"] = "objc",
		["Objective-C++"] = "objcpp",
		["Plain Text"] = "text"
	}

	local lang = map[language]
	if lang == nil then
		lang = string.lower(language)
	end

	return lang
end

-- Gets the icon for a language as well as the highlight group
-- @param name String : The language's name
function M.get_lang_icon(language)
	local map = {
		["C++"] = "cpp",
		["C#"] = "cs",
		["Objective-C"] = "objc",
		["Objective-C++"] = "objcpp",
		["Plain Text"] = "txt"
	}

	local ok, icon, color = pcall(function()
		local lang = map[language]
		if lang == nil then
			lang = string.lower(language)
		end
		return require'nvim-web-devicons'.get_icon_color("file." .. lang, lang)
	end)

	if not ok then
		return nil
	end
	return {icon, color}
end

return M
