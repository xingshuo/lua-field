return {
	["BaseAttr"] = {
		["create_time"] = {
			["__tags"] = 17, -- Persistent.NOW | Sync.OWN
			["__type"] = "number",
		},
		["lv"] = {
			["__tags"] = 161, -- Persistent.FIX | Persistent.SNAPINFO_FIX | Sync.OWN
			["__type"] = "number",
		},
		["nickname"] = {
			["__tags"] = 162, -- Persistent.FIX | Persistent.SNAPINFO_FIX | Sync.ALL
			["__type"] = "string",
		},
		["offline_time"] = {
			["__tags"] = 160, -- Persistent.FIX | Persistent.SNAPINFO_FIX
			["__type"] = "number",
		},
	},
	["Player"] = {
		["activity_award"] = {
			["__keytype"] = "number",
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "map",
			["__valuetype"] = "RewardItemData",
		},
		["base_attr"] = {
			["__tags"] = 179, -- Persistent.FIX | Persistent.NOW | Persistent.SNAPINFO_FIX | Sync.ALL | Sync.OWN
			["__type"] = "BaseAttr",
		},
		["is_newbie"] = {
			["__tags"] = 16, -- Persistent.NOW
			["__type"] = "boolean",
		},
		["task_bag"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "TaskBag",
		},
	},
	["RewardItemData"] = {
		["count"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "number",
		},
		["id"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "number",
		},
		["is_gotten"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "boolean",
		},
	},
	["TaskBag"] = {
		["got_tasks"] = {
			["__keytype"] = "number",
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "map",
			["__valuetype"] = "TaskData",
		},
	},
	["TaskData"] = {
		["id"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "number",
		},
		["is_completed"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "boolean",
		},
		["progress"] = {
			["__tags"] = 33, -- Persistent.FIX | Sync.OWN
			["__type"] = "number",
		},
	},
}