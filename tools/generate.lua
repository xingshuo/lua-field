local Utils = require("pkg.Utils")
local Const = require("pkg.Const")

local sformat = string.format

local delimiter = package.config:sub(1,1)
local IS_WINDOWS = delimiter == "\\"

local function parseInputs(...)
	local protoDir, outputDir = ...
	if not protoDir then
		protoDir = IS_WINDOWS and "examples\\proto" or "examples/proto"
	end
	if not outputDir then
		outputDir = IS_WINDOWS and "examples\\res" or "examples/res"
	end
	return protoDir, outputDir
end

local protoDir, outputDir = parseInputs(...)
local tagsFile = "tags.lua"
local outputFile = "typedef.lua"

local function joinPath(...)
	return table.concat({...}, delimiter)
end

local function listDir(dir, suffix)
	local cmd = sformat("dir %s%s*.%s", dir, delimiter, suffix)
	local f = io.popen(cmd)
	local stream = f:read("*a")
	f:close()
	local files = {}
	local pattern = "([%w_]+%." .. suffix .. ")"
	for filename in string.gmatch(stream, pattern) do
		files[#files + 1] = filename
	end
	return files
end

local MAP_PATTERN = "^map<%s*(%a+),%s*(%a+)%s*>$"

local FieldInfoKeyList = {
	["type"] = true,
	["persistent"] = true,
	["sync"] = true,
}


local TagsDef = Utils.LoadFile(joinPath(protoDir, tagsFile))

local function generateConfig(configData)
	local structPool = {}
	local function parseMap(sType)
		local kt, vt = sType:match(MAP_PATTERN)
		assert(Const.KeyTypes[kt], kt)
		assert(Const.BasicTypes[vt] or structPool[vt], vt)
		return kt, vt
	end

	for struName, struData in pairs(configData) do
		if TagsDef[struName] == nil then -- 排除tags
			assert(type(struName) == "string")
			structPool[struName] = struData
		end
	end

	for struName, struData in pairs(structPool) do
		local stHeadCh = struName:sub(1, 1)
		assert(stHeadCh >= "A" and stHeadCh <= "Z", struName) -- struct 首字母必须大写
		for field, info in pairs(struData) do
			assert(type(field) == "string", field)
			local fdHeadCh = field:sub(1, 1):upper()
			assert(fdHeadCh >= "A" and fdHeadCh <= "Z", field) -- field只能以字母开头

			for k in pairs(info) do
				assert(FieldInfoKeyList[k], k)
			end
			local fdType = assert(info["type"])
			if not Const.BasicTypes[fdType] and not structPool[struName] then
				parseMap(fdType)
			end
			assert(info["persistent"] or info["sync"], field)
		end
	end

	local dumpTable = {}
	for struName, struData in pairs(structPool) do
		dumpTable[struName] = {}
		for field, info in pairs(struData) do
			local fdType = info["type"]
			if Const.BasicTypes[fdType] or structPool[fdType] then
				dumpTable[struName][field] = {
					["__type"] = info["type"],
					["__tags"] = (info["persistent"] or 0) | (info["sync"] or 0),
				}
			else -- map
				local kt, vt = parseMap(fdType)
				dumpTable[struName][field] = {
					["__type"] = "map",
					["__tags"] = (info["persistent"] or 0) | (info["sync"] or 0),
					["__keytype"] = kt,
					["__valuetype"] = vt,
				}
			end
		end
	end
	return dumpTable
end

local function prettySeriTable(T)
	local repeatTbl = {}
	local function seriTbl(tbl, prevIndex, index)
		local function _kvToStr(value)
			local t = type(value)
			if t == 'number' then
				return tostring(value)
			elseif t == 'string' then
				return string.format('%q', value)
			elseif t == 'boolean' then
				return value and 'true' or 'false'
			end
		end
		local function getTagsComment(tagsFlag)
			local comments = {}
			for typeName, defs in Utils.StablePairs(TagsDef) do
				for tagName, val in Utils.StablePairs(defs) do
					if (tagsFlag & val) ~= 0 then
						table.insert(comments, typeName .. "." .. tagName)
					end
				end
			end
			return table.concat(comments, " | ")
		end

		repeatTbl[tbl] = true
		local prevSpace = string.rep('	', prevIndex)
		local space = string.rep('	', index)
		local tmp = {}
		table.insert(tmp, '{\n')
		for k,v in Utils.StablePairs(tbl) do
			local key = _kvToStr(k)
			local value = _kvToStr(v)
			table.insert(tmp, space)
			table.insert(tmp, '[')
			table.insert(tmp, key)
			table.insert(tmp, '] = ')

			if value then
				table.insert(tmp, value)
			else
				assert(type(v) == 'table', v)
				if not repeatTbl[v] then
					table.insert(tmp, seriTbl(v, index, index + 1))
				else
					table.insert(tmp, "...")
				end
			end
			if k == "__tags" then
				table.insert(tmp, ', -- ' .. getTagsComment(v) .. "\n")
			else
				table.insert(tmp, ',\n')
			end
		end
		table.insert(tmp, prevSpace)
		table.insert(tmp, '}')
		return table.concat(tmp)
	end
	return seriTbl(T, 0, 1)
end


local env = Utils.LoadFile(joinPath(protoDir, tagsFile))
local typeDefs = listDir(protoDir, "lua")
for _, filename in ipairs(typeDefs) do
	if filename ~= tagsFile then
		env = Utils.LoadFile(joinPath(protoDir, filename), env)
	end
end

local dumpTbl = generateConfig(env)
local data = "return " .. prettySeriTable(dumpTbl)
Utils.WriteFile(joinPath(outputDir, outputFile), data)