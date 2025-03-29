local srep = string.rep
local type = type

local M = {}

function M.TableTostr(mt, max_floor, cur_floor)
	cur_floor = cur_floor or 1
	max_floor = max_floor or 10
	if max_floor and cur_floor > max_floor then
		return tostring(mt)
	end
	local str = (cur_floor == 1) and srep("--", max_floor) .. "{\n" or "{\n"

	for k,v in pairs(mt) do
		if type(v) == 'table' then
			v = M.TableTostr(v, max_floor, cur_floor+1)
		else
			if type(v) == 'string' then
				v = "'" .. v .. "'\n"
			else
				v = tostring(v) .. "\n"
			end
		end
		if type(k) == 'string' then
			k = "'" .. k .. "'"
		end
		str = str .. srep("--", cur_floor) .. "[" .. k .. "] = " .. v
	end

	str = str .. srep("--", cur_floor-1) .. "}\n"

	return str
end

function M.TableIsSame(t1, t2)
	-- check t1 <= t2
	for k1,v1 in pairs(t1) do
		local v2 = t2[k1]
		if type(v2) ~= type(v1) then
			return false
		end
		if type(v1) == 'table' then
			assert(v1 ~= t1) -- 防止成环引用
			if not M.TableIsSame(v1, v2) then
				return false
			end
		else
			if v1 ~= v2 then
				return false
			end
		end
	end
	-- check t2 <= t1
	for k2,v2 in pairs(t2) do
		local v1 = t1[k2]
		if type(v1) ~= type(v2) then
			return false
		end
		if type(v2) == 'table' then
			assert(v2 ~= t2) -- 防止成环引用
			if not M.TableIsSame(v2, v1) then
				return false
			end
		else
			if v2 ~= v1 then
				return false
			end
		end
	end

	return true
end

function M.StablePairs(t)
	local function _stableNext(list)
		local k = list[list.i]
		if k ~= nil then
			list.i = list.i + 1
			return k, list.t[k]
		end
	end
	local keylist = {t = t, i = 1}
	for k in pairs(t) do
		keylist[#keylist + 1] = k
	end
	table.sort(keylist, function(ka, kb)
		local tka = type(ka)
		local tkb = type(kb)
		if tka == tkb then
			return ka < kb
		else
			return tka < tkb
		end
	end)

	return _stableNext, keylist
end

function M.ReadFile(file)
	local fh = io.open(file , "rb")
	assert(fh, file)
	local data = fh:read("*a")
	fh:close()
	return data
end

function M.WriteFile(file, data)
	local fh = io.open(file , "w+b")
	assert(fh, file)
	fh:write(data)
	fh:close()
end

function M.LoadFile(path, env)
	local data = M.ReadFile(path)
	env = env or {}
	local f, errmsg = load(data, "@".. path, "bt", env)
	if not f then
		error(string.format('config name: %s err: %s data:%s', path, errmsg, data), 2)
	end
	f()
	return env
end

return M