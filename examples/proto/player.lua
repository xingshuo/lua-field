
Player = {
	is_newbie = {
		type = "boolean",
		persistent = Persistent.NOW,
	},

	base_attr = {
		type = "BaseAttr",
		persistent = Persistent.FIX | Persistent.NOW | Persistent.SNAPINFO_FIX,
		sync = Sync.OWN | Sync.ALL,
	},

	task_bag = {
		type = "TaskBag",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},

	activity_award = {
		type = "map<number, RewardItemData>",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},
}

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

TaskBag = {
	got_tasks = {
		type = "map<number, TaskData>",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	}
}

TaskData = {
	id = {
		type = "number",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},
	progress = {
		type = "number",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},
	is_completed = {
		type = "boolean",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	}
}

RewardItemData = {
	id = {
		type = "number",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},
	count = {
		type = "number",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},
	is_gotten = {
		type = "boolean",
		persistent = Persistent.FIX,
		sync = Sync.OWN,
	},
}