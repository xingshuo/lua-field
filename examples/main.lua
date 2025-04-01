local Typedef = require("pkg.Typedef")
local Factory = require("pkg.Factory")
local Utils = require("pkg.Utils")

local Propdef = require("examples.res.typedef")
Typedef.SetTypedef(Propdef)

local TagsDef = Utils.LoadFile("examples/proto/tags.lua")
Typedef.SetTagdef(TagsDef)

local function test1()
	local rawData = {
		create_time = os.time(),
		nickname = "lakefu",
		lv = 35,
		offline_time = 0,
	}
	local attrObj = Factory.CreateObj(rawData, "BaseAttr")
	assert(Utils.TableIsSame(rawData, attrObj))
	attrObj.offline_time = -1
	attrObj.lv = 40

	local updateLogs = Factory.FetchModifyLog(attrObj, TagsDef.Persistent.FIX, true, true)
	local expect = {
		["$set"] = {
			offline_time = -1,
			lv = 40,
		},
	}
	assert(Utils.TableIsSame(updateLogs, expect), Utils.TableTostr(updateLogs))
	updateLogs = Factory.FetchModifyLog(attrObj, TagsDef.Persistent.FIX, true, true)
	expect = nil
	assert(updateLogs == expect)

	updateLogs = Factory.FetchModifyLog(attrObj, TagsDef.Sync.OWN, true, true)
	expect = {
		["$set"] = {
			lv = 40,
		},
	}
	assert(Utils.TableIsSame(updateLogs, expect), Utils.TableTostr(updateLogs))
	updateLogs = Factory.FetchModifyLog(attrObj, TagsDef.Sync.OWN, true, true)
	expect = nil
	assert(updateLogs == expect)
end

local function test2()
	local playerData = {
		is_newbie = true,
		activity_award = {},
	}
	local playerObj = Factory.CreateObj(playerData, "Player")
	local taskBag = {
		got_tasks = {
			[1001] = {
				id = 1001,
				progress = 3,
				is_completed = false,
			},
			[1002] = {
				id = 1002,
				progress = 4,
				is_completed = true,
			},
		}
	}
	playerObj.task_bag = taskBag -- test set rawdata value
	local updateLogs = Factory.FetchModifyLog(playerObj, TagsDef.Persistent.FIX| TagsDef.Sync.OWN, true, true)
	local expect = {
		["$set"] = {
			task_bag = taskBag,
		},
	}
	assert(Utils.TableIsSame(updateLogs, expect), Utils.TableTostr(updateLogs))

	local attrData = {
		create_time = os.time(),
		nickname = "lakefu",
		lv = 35,
		offline_time = 0,
	}
	local attrObj = Factory.CreateObj(attrData, "BaseAttr")
	playerObj.base_attr = attrObj -- test set obj value

	local updateLogs = Factory.FetchModifyLog(playerObj, Typedef.GetFullTagsFlag(), true, true)
	local expect = {
		["$set"] = {
			base_attr = attrData,
		},
	}
	assert(Utils.TableIsSame(updateLogs, expect), Utils.TableTostr(updateLogs))
	-- Factory.ClearDirtyTags(playerObj)

	local actAwardData = {
		[10001] = {
			id = 10001,
			count = 10,
			is_gotten = true,
		},
		[20001] = {
			id = 20001,
			count = 2,
			is_gotten = false,
		},
	}
	for k, v in pairs(actAwardData) do
		playerObj.activity_award[k] = v
	end

	local updateLogs = Factory.FetchModifyLog(playerObj, TagsDef.Sync.OWN|TagsDef.Persistent.FIX, true, true)
	local expect = {
		["$set"] = {
			["activity_award.10001"] = actAwardData[10001],
			["activity_award.20001"] = actAwardData[20001],
		},
	}
	assert(Utils.TableIsSame(updateLogs, expect), Utils.TableTostr(updateLogs))

	Factory.SetDirtyCallback(playerObj, function (modifyDoc, modifyKey, oldVal, tagsFlag)
		if modifyKey == "is_newbie" then
			assert(modifyDoc == playerObj)
			assert(tagsFlag == TagsDef.Persistent.NOW)
		elseif modifyKey == "progress" then
			assert(oldVal == 3)
			assert(tagsFlag == TagsDef.Persistent.FIX|TagsDef.Sync.OWN)
		elseif modifyKey == "is_completed" then
			assert(oldVal == false)
			assert(tagsFlag == TagsDef.Persistent.FIX|TagsDef.Sync.OWN)
		elseif modifyKey == 1002 then
			local expect = {
				id = 1002,
				progress = 4,
				is_completed = true,
			}
			assert(Utils.TableIsSame(oldVal, expect), Utils.TableTostr(oldVal))
			assert(tagsFlag == TagsDef.Persistent.FIX|TagsDef.Sync.OWN)
		end

		print(string.format("modify field [%s] => %s", modifyKey, modifyDoc[modifyKey]))
	end)
	playerObj.is_newbie = false
	playerObj.task_bag.got_tasks[1001].progress = 4
	playerObj.task_bag.got_tasks[1001].is_completed = true
	playerObj.task_bag.got_tasks[1002] = nil
	local expect = {
		got_tasks = {
			[1001] = {
				id = 1001,
				progress = 4,
				is_completed = true,
			},
		}
	}
	assert(Utils.TableIsSame(playerObj.task_bag, expect), Utils.TableTostr(playerObj.task_bag))
	local updateLogs = Factory.FetchModifyLog(playerObj, TagsDef.Sync.OWN|TagsDef.Persistent.FIX, true, true)
	local expect = {
		["$set"] = {
			["task_bag.got_tasks.1001.progress"] = 4,
			["task_bag.got_tasks.1001.is_completed"] = true,
		},
		["$unset"] = {
			["task_bag.got_tasks.1002"] = true,
		},
	}
	assert(Utils.TableIsSame(updateLogs, expect), Utils.TableTostr(updateLogs))

	local seriData = Factory.PackRawData(playerObj, TagsDef.Persistent.FIX)
	local expect = {
		base_attr = {
			nickname = "lakefu",
			lv = 35,
			offline_time = 0,
		},
		task_bag = {
			got_tasks = {
				[1001] = {
					id = 1001,
					progress = 4,
					is_completed = true,
				},
			},
		},
		activity_award = actAwardData,
	}
	assert(Utils.TableIsSame(seriData, expect), Utils.TableTostr(seriData))

	local seriData = Factory.PackRawData(playerObj, TagsDef.Persistent.FIX, true)
	local expect = {
		base_attr = {
			nickname = "lakefu",
			lv = 35,
			offline_time = 0,
		},
		task_bag = {
			got_tasks = {
				["1001"] = {
					id = 1001,
					progress = 4,
					is_completed = true,
				},
			},
		},
		activity_award = {
			["10001"] = {
				id = 10001,
				count = 10,
				is_gotten = true,
			},
			["20001"] = {
				id = 20001,
				count = 2,
				is_gotten = false,
			},
		},
	}
	assert(Utils.TableIsSame(seriData, expect), Utils.TableTostr(seriData))

	local seriData = Factory.PackRawData(playerObj, TagsDef.Persistent.SNAPINFO_FIX, true)
	local expect = {
		base_attr = {
			nickname = "lakefu",
			lv = 35,
			offline_time = 0,
		},
	}
	assert(Utils.TableIsSame(seriData, expect), Utils.TableTostr(seriData))
end

test1()
print("==========test1 done=======")
test2()
print("==========test2 done=======")