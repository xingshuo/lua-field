--[[
	为了处理td数据热更，对导出数据的二次封装(DAO)
]]
local Const = require("pkg.Const")

local sformat = string.format


local basicMeta = {} -- number string boolean
basicMeta.__index = basicMeta

function basicMeta.New(data)
	local o = {
		data = data,
	}
	setmetatable(o, basicMeta)
	return o
end

function basicMeta:Tags()
	return self.data["__tags"]
end

function basicMeta:Type()
	return self.data["__type"]
end


local structMeta = {}
structMeta.__index = structMeta


local mapMeta = {}
mapMeta.__index = mapMeta

local function _checkMapDef(data)
	local kt = assert(data["__keytype"])
	assert(Const.KeyTypes[kt], sformat("invalid map key type: %s", kt))

	local vt = assert(data["__valuetype"])
	assert(not Const.InvalidMapValueTypes[vt], sformat("invalid map val type: %s", vt))

	local tags = assert(data["__tags"])
	assert(type(tags) == "number" and tags ~= 0, sformat("invalid map tag: %s", tags))
end

function mapMeta.New(data)
	_checkMapDef(data)
	local o = {
		data = data,
		value = false,
	}
	setmetatable(o, mapMeta)
	return o
end

function mapMeta:Type()
	return "map"
end

function mapMeta:KeyType()
	return self.data["__keytype"]
end

function mapMeta:ValueDef()
	if self.value then
		return self.value
	end
	local vt = self.data["__valuetype"]
	local tags = self:Tags()
	if Const.BasicTypes[vt] then
		self.value = basicMeta.New({__type = vt, __tags = tags})
	else -- struct
		self.value = structMeta.New(vt, tags)
	end
	return self.value
end

function mapMeta:Tags()
	return self.data["__tags"]
end


local typedefData

function structMeta.New(stName, tags)
	assert(typedefData[stName], stName)
	local o = {
		stName = stName,
		tags = tags,
		fields = {},
	}
	setmetatable(o, structMeta)
	return o
end


function structMeta:GetField(name)
	if not self.fields[name] then
		local stDef = assert(typedefData[self.stName], sformat("td no struct find: %s field: %s", self.stName, name))
		local fdDef = assert(stDef[name], sformat("td no st-field find: %s field: %s", self.stName, name))
		
		local fdType = assert(fdDef.__type, sformat("td config err '__type' needed: %s field: %s", self.stName, name))
		if Const.BasicTypes[fdType] then
			self.fields[name] = basicMeta.New(fdDef)
		elseif fdType == "map" then
			self.fields[name] = mapMeta.New(fdDef)
		else -- struct
			local tags = assert(fdDef.__tags)
			self.fields[name] = structMeta.New(fdType, tags)
		end
	end
	return self.fields[name]
end

-- root struct have no tags
function structMeta:Tags()
	return self.tags
end

function structMeta:Type()
	return self.stName
end


local Api = {}

function Api.SetTypedef(t)
	typedefData = t
end

local nFullTagsFlag = nil

function Api.SetTagdef(t)
	nFullTagsFlag = 0
	for _, tag in pairs(t.Sync) do
		nFullTagsFlag = nFullTagsFlag | tag
	end

	for _, tag in pairs(t.Persistent) do
		nFullTagsFlag = nFullTagsFlag | tag
	end
end

function Api.GetFullTagsFlag()
	return assert(nFullTagsFlag)
end

local structPool = {}

function Api.GetTypedef(typename)
	if not structPool[typename] then
		structPool[typename] = structMeta.New(typename)
	end
	return structPool[typename]
end

return Api