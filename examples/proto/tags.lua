-- 按位标识定义Tag, 最多支持64种

-- 1 ~ 4 Bits
Sync = {
	OWN = 0x1,
	ALL = 0x2,
}

-- 5 ~ 8 Bits
Persistent = {
	-- Entity数据
	NOW = 0x10,
	FIX = 0x20,
	-- Entity Snapinfo
	SNAPINFO_NOW = 0X40,
	SNAPINFO_FIX = 0x80,
}