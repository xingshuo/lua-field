local Const = require("pkg.Const")
local Typedef = require("pkg.Typedef")

local sformat = string.format
local assert = assert
local type = type
local tonumber = tonumber
local next = next
local tostring = tostring
local tremove = table.remove

local BSON_OBJECTID_FIELD = "_id"

local mapMeta = {}
local structMeta = {}

local function _newStructObj(oTypedef, root)
	local obj = {
		__realdata = {},
		__dirtyflags = {},
		__typedef = oTypedef,
		__dirtycallback = false,
		__root = root or false,
	}
	setmetatable(obj, structMeta)
	return obj
end

local function _newMapObj(oTypedef, root)
	local obj = {
		__realdata = {},
		__dirtyflags = {},
		__keytype = oTypedef:KeyType(),
		__valuedef = oTypedef:ValueDef(),
		__root = assert(root),
	}
	setmetatable(obj, mapMeta)
	return obj
end

local function _checkBsonObjectID(id)
	assert(type(id) == "string", sformat("bson objectID type err: [%s]", id))
	local len = #id
	assert(len == 14, sformat("bson objectID len err: [%d], [%s] ", len, id))
	assert(id:byte(1) == 0 and id:byte(2) == 7, sformat("bson objectID data err: [%s]", id))
end

local function _checkValueType(val, expectType, message)
	local vt = type(val)
	local typename = Const.BasicTypes[expectType]
	if typename then
		assert(vt == typename, sformat("%s actual: %s(%s), expect type: %s", message, val, vt, expectType))
	else -- struct, map
		assert(vt == "table", sformat("%s actual: %s(%s), expect type: %s", message, val, vt, expectType))
	end
end


function mapMeta:__index(k)
	if mapMeta[k] then
		return mapMeta[k]
	end
	local realdata = self.__realdata
	return realdata[k]
end

function mapMeta:__newindex(k, v)
	local realdata = self.__realdata
	local oldVal = realdata[k]
	if oldVal == v then -- no modify
		return
	end

	local kt = self.__keytype
	assert(type(k) == kt, sformat("get map key: %s, %s type expected", k, kt))
	local oValDef = self.__valuedef
	local vtags = oValDef:Tags()
	local root = self.__root
	-- set dirty flags
	local dirtyFlags = self.__dirtyflags
	if v == nil then -- delete
		realdata[k] = nil
		dirtyFlags[k] = vtags
		if root.__dirtycallback then
			root.__dirtycallback(self, k, oldVal, vtags)
		end
		return
	end
	local vt = oValDef:Type()
	_checkValueType(v, vt, "invalid map value")
	if Const.BasicTypes[vt] then
		realdata[k] = v
	else -- struct
		local oStru = _newStructObj(oValDef, root)
		oStru:_load(v)
		realdata[k] = oStru
	end
	-- NOTICE: 上面有可能会报错, 出错的数据不应该标脏
	dirtyFlags[k] = vtags
	if root.__dirtycallback then
		root.__dirtycallback(self, k, oldVal, vtags)
	end
end

function mapMeta:__pairs()
	return next, self.__realdata, nil
end

function mapMeta:__len()
	return #self.__realdata
end

function mapMeta:__ipairs()
	return ipairs(self.__realdata)
end

function mapMeta:_load(data, keyFilter)
	if not data then
		return
	end
	local kt = self.__keytype
	local oValDef = self.__valuedef
	local vt = oValDef:Type()
	local realdata = self.__realdata

	if Const.BasicTypes[vt] then
		for k, v in pairs(data) do
			if keyFilter then
				k = keyFilter(k, kt)
			end
			assert(type(k) == kt, sformat("load map key: %s, %s type expected", k, kt))
			realdata[k] = v
		end
	else -- struct
		for k, v in pairs(data) do
			if keyFilter then
				k = keyFilter(k, kt)
			end
			assert(type(k) == kt, sformat("load map key: %s, %s type expected", k, kt))
			local oStru = _newStructObj(oValDef, self.__root)
			oStru:_load(v, keyFilter)
			realdata[k] = oStru
		end
	end
end

function mapMeta:_save(nTagsFlag, keyFilter)
	local oValDef = self.__valuedef
	local vtags = oValDef:Tags()

	local data = {}
	if (nTagsFlag & vtags) == 0 then
		return data
	end

	local vt = oValDef:Type()
	local realdata = self.__realdata
	if Const.BasicTypes[vt] then
		for k, v in pairs(realdata) do
			if keyFilter then
				k = keyFilter(k)
			end
			data[k] = v
		end
	else -- struct
		for k, v in pairs(realdata) do
			if keyFilter then
				k = keyFilter(k)
			end
			data[k] = v:_save(nTagsFlag, keyFilter)
		end
	end

	return data
end

function mapMeta:_clearDirtyTags(nTagsFlag, isRecursive)
	local dirtyFlags = self.__dirtyflags
	for key, flag in pairs(dirtyFlags) do
		if (nTagsFlag & flag) ~= 0 then
			dirtyFlags[key] = (~nTagsFlag) & flag
		end
	end
	if isRecursive then
		local realdata = self.__realdata
		for _, v in pairs(realdata) do
			if type(v) == "table" then
				v:_clearDirtyTags(nTagsFlag, isRecursive)
			end
		end
	end
end

function mapMeta:_fetchDirtyDoc(nTagsFlag)
	local oValDef = self.__valuedef
	local vt = oValDef:Type()
	local realdata = self.__realdata

	local dirtyDoc = {}
	if Const.BasicTypes[vt] then
		for k, v in pairs(realdata) do
			dirtyDoc[k] = v
		end
	else -- struct
		for k, v in pairs(realdata) do
			dirtyDoc[k] = v:_fetchDirtyDoc(nTagsFlag)
		end
	end

	return dirtyDoc
end


function structMeta:__index(k)
	if structMeta[k] then
		return structMeta[k]
	end
	local realdata = self.__realdata
	return realdata[k]
end

function structMeta:__newindex(k, v)
	local realdata = self.__realdata
	local oldVal = realdata[k]
	if oldVal == v then -- no modify
		return
	end
	assert(type(k) == "string", sformat("get struct field key: %s, string expected", k))
	if k == BSON_OBJECTID_FIELD then -- FIXME: @lake 兼容mongo objectId, 该字段不变, 不打脏标记
		_checkBsonObjectID(v)
		realdata[k] = v
		return
	end
	local root = self.__root or self
	local stDef = self.__typedef
	local oValDef = stDef:GetField(k)
	local vtags = oValDef:Tags()
	-- set dirty flags
	local dirtyFlags = self.__dirtyflags
	if v == nil then -- delete
		realdata[k] = nil
		dirtyFlags[k] = vtags
		if root.__dirtycallback then
			root.__dirtycallback(self, k, oldVal, vtags)
		end
		return
	end
	local vt = oValDef:Type()
	_checkValueType(v, vt, "invalid struct field value")
	if Const.BasicTypes[vt] then
		realdata[k] = v
	elseif vt == "map" then
		local oMap = _newMapObj(oValDef, root)
		oMap:_load(v)
		realdata[k] = oMap
	else -- struct
		local oStru = _newStructObj(oValDef, root)
		oStru:_load(v)
		realdata[k] = oStru
	end
	-- NOTICE: 上面有可能会报错, 出错的数据不应该标脏
	dirtyFlags[k] = vtags
	if root.__dirtycallback then
		root.__dirtycallback(self, k, oldVal, vtags)
	end
end

function structMeta:__pairs()
	return next, self.__realdata, nil
end

function structMeta:_load(data, keyFilter)
	if not data then
		return
	end
	local root = self.__root or self
	local realdata = self.__realdata
	local stDef = self.__typedef
	for k, v in pairs(data) do
		assert(type(k) == "string", sformat("load struct field key: %s, string expected", k))
		if k == BSON_OBJECTID_FIELD then -- FIXME: @lake 兼容mongo objectId
			_checkBsonObjectID(v)
			realdata[k] = v
			goto coroutine
		end
		local oValDef = stDef:GetField(k)
		local vt = oValDef:Type()
		if Const.BasicTypes[vt] then
			assert(type(v) == vt, sformat("load struct field key: %s val: %s, %s expected", k, v, vt))
			realdata[k] = v
		elseif vt == "map" then
			assert(type(v) == "table", sformat("load struct field key: %s val: %s, table expected", k, v))
			local oMap = _newMapObj(oValDef, root)
			oMap:_load(v, keyFilter)
			realdata[k] = oMap
		else -- struct
			assert(type(v) == "table", sformat("load struct field key: %s val: %s, table expected", k, v))
			local oStru = _newStructObj(oValDef, root)
			oStru:_load(v, keyFilter)
			realdata[k] = oStru
		end
		::coroutine::
	end
end

function structMeta:_save(nTagsFlag, keyFilter)
	local realdata = self.__realdata
	local stDef = self.__typedef

	local data = {}
	for k, v in pairs(realdata) do
		local oValDef = stDef:GetField(k)
		local vtags = oValDef:Tags()
		if (nTagsFlag & vtags) ~= 0 then
			local vt = oValDef:Type()
			if Const.BasicTypes[vt] then
				data[k] = v
			else -- map, struct
				data[k] = v:_save(nTagsFlag, keyFilter)
			end
		end
	end

	return data
end

function structMeta:_clearDirtyTags(nTagsFlag, isRecursive)
	local dirtyFlags = self.__dirtyflags
	for key, flag in pairs(dirtyFlags) do
		if (nTagsFlag & flag) ~= 0 then
			dirtyFlags[key] = (~nTagsFlag) & flag
		end
	end
	if isRecursive then
		local realdata = self.__realdata
		for _, v in pairs(realdata) do
			if type(v) == "table" then
				v:_clearDirtyTags(nTagsFlag, isRecursive)
			end
		end
	end
end

function structMeta:_fetchDirtyDoc(nTagsFlag)
	local stDef = self.__typedef
	local realdata = self.__realdata

	local dirtyDoc = {}
	for k, v in pairs(realdata) do
		local oValDef = stDef:GetField(k)
		local vtags = oValDef:Tags()
		if (nTagsFlag & vtags) ~= 0 then
			if type(v) == "table" then -- struct, map
				dirtyDoc[k] = v:_fetchDirtyDoc(nTagsFlag)
			else
				dirtyDoc[k] = v
			end
		end
	end

	return dirtyDoc
end

function structMeta:_setDirtyCallback(callback)
	assert(not self.__root, "must set dirty callback on root struct")
	if callback then
		self.__dirtycallback = callback
	else
		self.__dirtycallback = false
	end
end

local function _copyList(list, appendVal)
	local new = {}
	local len = #list
	for i = 1, len do
		new[i] = list[i]
	end
	new[len + 1] = appendVal
	return new
end

local function _fetchModifyLog(obj, nTagsFlag, isClearDirtyTags, logList, parentPathList)
	local dirtyFlags = obj.__dirtyflags
	local realdata = obj.__realdata
	parentPathList = parentPathList or {}

	for key, flag in pairs(dirtyFlags) do
		if (nTagsFlag & flag) ~= 0 then
			local path = _copyList(parentPathList, key)
			local val = realdata[key]
			if val ~= nil then
				if type(val) == "table" then
					local realVal = val:_fetchDirtyDoc(nTagsFlag)
					logList[#logList + 1] = {path, realVal}
				else
					logList[#logList + 1] = {path, val}
				end
			else
				logList[#logList + 1] = {path}
			end
		end
	end

	if isClearDirtyTags then
		dirtyFlags = {}
		for key, flag in pairs(obj.__dirtyflags) do
			dirtyFlags[key] = flag
		end
		obj:_clearDirtyTags(nTagsFlag)
	end

	for key, val in pairs(realdata) do
		if (dirtyFlags[key] == nil or (nTagsFlag & dirtyFlags[key]) == 0) and type(val) == "table" then
			parentPathList[#parentPathList + 1] = key
			_fetchModifyLog(val, nTagsFlag, isClearDirtyTags, logList, parentPathList)
			tremove(parentPathList)
		end
	end

	return logList
end


local Api = {}

local function _mongoToUsrKey(key, expectedType)
	if expectedType == "number" then
		return tonumber(key)
	end
	return key
end

-- 生成LuaField代理对象
function Api.CreateObj(data, typename, fromMongo)
	data = data or {}
	local oTypedef = Typedef.GetTypedef(typename)
	local obj = _newStructObj(oTypedef)
	if fromMongo then
		obj:_load(data, _mongoToUsrKey)
	else
		obj:_load(data)
	end
	return obj
end

local function _usrToMongoKey(key)
	if type(key) == "number" then
		return tostring(key)
	end
	return key
end

-- 根据指定tagsFlag, 获取LuaField原始数据
function Api.PackRawData(obj, nTagsFlag, toMongo)
	if toMongo then
		return obj:_save(nTagsFlag, _usrToMongoKey)
	else
		return obj:_save(nTagsFlag)
	end
end

-- 清除代理对象指定tags脏标记
function Api.ClearDirtyTags(obj, nTagsFlag)
	nTagsFlag = nTagsFlag or Typedef.GetFullTagsFlag()
	obj:_clearDirtyTags(nTagsFlag, true)
end

-- 为struct对象及其所有子孙节点设置field修改事件监听回调
-- callback: function (modifyDoc, modifyKey, oldValue, valueTags)
function Api.SetDirtyCallback(obj, callback)
	obj:_setDirtyCallback(callback)
end

--[[
	功能: 获取原始数据修改信息
	返回值: modify logList. if logList is empty, return nil. else if toMongo is true, return mongodb update sql. else return logList
	modify loglist格式:
	{
		{pathList1, value1},
		{pathList2, value2},
		{pathList3, value3},
		...
	} value为nil表示删除
	Eg: logList = {
		{{"is_newbie"}},  -- Delete: obj.is_newbie = nil
		{{"offline_time"}, 0}, -- Update: obj.offline_time = 0
		{{"item_bag", 1001}, {id = 1001, state = 0}}, -- update: obj.item_bag[1001] = {id = 1001, state = 0}
	}
]]
function Api.FetchModifyLog(obj, nTagsFlag, isClearDirtyTags, toMongo)
	local logList = {}
	_fetchModifyLog(obj, nTagsFlag, isClearDirtyTags, logList)
	if #logList == 0 then
		return
	end
	if toMongo then
		local mSet = {}
		local mUnset = {}
		for _, item in ipairs(logList) do
			local pathList = item[1]
			local val = item[2]
			local key = table.concat(pathList, ".")
			if val ~= nil then
				mSet[key] = val
			else
				mUnset[key] = true
			end
		end
		local updates = {}
		if next(mSet) ~= nil then
			updates["$set"] = mSet
		end
		if next(mUnset) ~= nil then
			updates["$unset"] = mUnset
		end
		return updates
	end
	return logList
end

return Api