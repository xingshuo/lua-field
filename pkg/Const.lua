
local M = {}

M.BasicTypes = {
	["number"] = "number",
	["string"] = "string",
	["boolean"] = "boolean",
}

M.KeyTypes = {
	["number"] = true,
	["string"] = true,
}

-- NOTICE: @lake 暂不支持map直接嵌套
M.InvalidMapValueTypes = {
	["map"] = true,
}

return M