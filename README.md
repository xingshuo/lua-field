# LuaField
* 基于IDL描述每个Entity属性类型和Tag标识，利用lua metatable hook属性读写操作, 提供Entity属性存盘和CS属性同步功能的基础支持

## 功能支持
* 基于Entity属性IDL定义 和 原始数据创建代理对象，通过代理对象读写数据与原生lua table一致：支持table方式读写数据、pairs遍历、取长度(#)、ipairs遍历(高版本lua不支持__ipairs元方法，需要单独处理下)
* 通过Entity属性IDL定义，约束每个field类型及关联的Tags标识，属性字段加载或修改时，会基于IDL描述做类型检查
* Entity属性修改自动标脏，并支持基于脏标记和IDL描述的Tags标识生成Modify Patch（存盘目前只支持生成mongodb的修改补丁）
* 基于IDL导入、导出Entity存盘属性数据和CS间同步属性数据（如从mongodb加载的bson格式数据，会根据IDL定义自动将number类型的key从string还原成number，同理数据写入mongodb时，也会按bson格式把number类型的key转成string，业务无感知）

## 类型支持
* 基础类型：number、string、boolean
* 复合类型：struct、map

## 注意事项
* 属性定义只能以struct类型作为根节点，且struct类型只能以string作为field名
* map类型只能以number 或 string类型做key，只支持基础类型 或 struct类型做value（map目前不支持直接嵌套map，只能通过定义struct类型的value，在内部二次包装来实现）
* 每个属性字段支持同时标记多个Tag（按位标记, 最多支持64种不同Tag）, 当某个属性字段发生修改，其IDL定义的全部Tag自动标脏，每个属性字段不同Tag之间标脏与清理脏标记完全独立

## 接口
* CreateObj(rawData, typename, fromMongo) -- 基于原始数据生成代理对象，类似ORM
* PackRawData(obj, nTagsFlag, toMongo)    -- 按指定的tags标识打包原始数据
* ClearDirtyTags(obj, nTagsFlag)          -- 按指定的tags标识清理脏标记，不指定nTagsFlag默认清除全部Tags标识脏标记
* SetDirtyCallback(obj, callback)         -- 为根节点对象及其所有子孙节点设置field修改事件监听回调. callback参数: function (modifyDoc, modifyKey, oldValue, valueTags)
* FetchModifyLog(obj, nTagsFlag, isClearDirtyTags, toMongo) -- 获取原始数据修改补丁

## 关于IDL定义
* 默认支持的IDL描述文件格式为lua
* 为了方便后续将IDL文件扩展为protobuf、json、sproto等格式，将IDL定义和代码逻辑读取的配置资源做了隔离，提供了基于lua IDL导出资源文件的脚本
```bash
lua tools/generate.lua
```

## 使用示例
* Tags定义
```lua
-- examples/proto/tags.lua
Sync = {
	OWN = 0x1,
	ALL = 0x2,
}

Persistent = {
	-- Entity数据
	NOW = 0x10,
	FIX = 0x20,
	-- Entity Snapinfo
	SNAPINFO_NOW = 0X40,
	SNAPINFO_FIX = 0x80,
}
```
* Entity属性定义
```lua
-- examples/proto/player.lua
BaseAttr = {
	create_time = {
		type = "number",
		persistent = Persistent.NOW,
		sync = Sync.OWN,
	},
	nickname = {
		type = "string",
		persistent = Persistent.FIX | Persistent.SNAPINFO_FIX,
		sync = Sync.ALL,
	},
	lv = {
		type = "number",
		persistent = Persistent.FIX | Persistent.SNAPINFO_FIX,
		sync = Sync.OWN,
	},
	offline_time = {
		type = "number",
		persistent = Persistent.FIX | Persistent.SNAPINFO_FIX,
	}
}
```
* Api示例
```lua

local rawData = {
	create_time = 0,
	nickname = "lakefu",
	lv = 35,
	offline_time = 0,
}

-- 创建代理对象
local attrObj = Factory.CreateObj(rawData, "BaseAttr")
-- 遍历
for field, value in pairs(attrObj) do
	print("field: [", field, "] value: [", value, "]")
end
--[[
Output:
	field: [create_time] value: [0]
	field: [nickname] value: [lakefu]
	field: [lv] value: [35]
	field: [offline_time] value: [0]
]]

-- 修改
attrObj.offline_time = -1
attrObj.lv = 40

local updateLogs = Factory.FetchModifyLog(attrObj, Persistent.FIX, false, true)
local expect = {
	["$set"] = {
		offline_time = -1,
		lv = 40,
	},
}

assert(Utils.TableIsSame(updateLogs, expect))

local updateLogs = Factory.FetchModifyLog(attrObj, Sync.OWN, false, true)
local expect = {
	["$set"] = {
		lv = 40,
	},
}
assert(Utils.TableIsSame(updateLogs, expect))

-- 打包原始数据
local seriData = Factory.PackRawData(attrObj, Persistent.FIX)
local expect = {
	nickname = "lakefu",
	lv = 40,
	offline_time = -1,
}
assert(Utils.TableIsSame(seriData, expect))

-- 清理脏标记
Factory.ClearDirtyTags(obj)
local updateLogs = Factory.FetchModifyLog(attrObj, Typedef.GetFullTagsFlag(), false, true)
local expect = nil
assert(updateLogs == expect)

-- 设置field修改事件监听回调
Factory.SetDirtyCallback(attrObj, function(modifyDoc, modifyKey, oldVal, tagsFlag)
	print(string.format("modify field [%s] from %s => %s tags: %d", modifyKey, oldVal, modifyDoc[modifyKey], tagsFlag))
end)
attrObj.create_time = 10000
attrObj.nickname = "lilei"
attrObj.lv = 80
attrObj.offline_time = 30000
--[[
Output:
	modify field [create_time] from 0 => 10000 tags: 17 -- Persistent.NOW | Sync.OWN
	modify field [nickname] from lakefu => lilei tags: 162, -- Persistent.FIX | Persistent.SNAPINFO_FIX | Sync.ALL
	modify field [lv] from 40 => 80 tags: 161, -- Persistent.FIX | Persistent.SNAPINFO_FIX | Sync.OWN
	modify field [offline_time] from -1 => 30000 tags: 160, -- Persistent.FIX | Persistent.SNAPINFO_FIX
]]

-- 清理field修改事件监听回调
Factory.SetDirtyCallback(attrObj, nil)
```

## Run Test
```bash
lua examples/main.lua
```
