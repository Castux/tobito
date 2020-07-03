local tobito = require "tobito"
local graph = require "graph"

local pack_fmt = "LbHH"
local top, bottom, win

local function load_all_data(data_str)

	top, bottom, win = {},{},{}
	local index = 1

	while index < #data_str do

		local state, w, t, b, next_index = string.unpack(pack_fmt, data_str, index)

		win[state] = w
		top[state] = t
		bottom[state] = b

		index = next_index
	end
end

local function max_for(values, func)

	local max = nil
	local best = nil

	for _,v in ipairs(values) do

		local value = func(v)
		if not best or value > max then
			best = v
			max = value
		end
	end

	return best
end

local function decide_state(state)

	local player = (state >> 24) & 0x3
	local m = (player == tobito.Top) and 1 or -1

	local children = graph[state].children

	local win_value = nil
	local acceptable_children = {}

	for _,child in pairs(children) do

		local child_value = m * win[child]
		if not win_value or child_value > win_value then
			win_value = child_value
			acceptable_children = {child}
		elseif child_value == win_value then
			table.insert(acceptable_children, child)
		end
	end

	local aggressive = max_for(acceptable_children, function(s) return m*top[s] end)
	local balanced = max_for(acceptable_children, function(s) return m*(top[s]-bottom[s]) end)
	local prudent = max_for(acceptable_children, function(s) return -m*bottom[s] end)

	return aggressive, balanced, prudent
end

local function debug_state(state)

	print(state)
	print(tobito.draw_state(state))

	local agr, bal, pru = decide_state(state)
	print(win[state], top[state], bottom[state], top[state] - bottom[state])

	print ""
	print("Aggressive:", agr)
	print(tobito.draw_state(agr))
	print(win[agr], top[agr], bottom[agr], top[agr] - bottom[agr])

	print ""
	print("Balanced:", bal)
	print(tobito.draw_state(bal))
	print(win[bal], top[bal], bottom[bal], top[bal] - bottom[bal])

	print ""
	print("Prudent:", pru)
	print(tobito.draw_state(pru))
	print(win[pru], top[pru], bottom[pru], top[pru] - bottom[pru])

end

local ai_fmt = "LLLL"

local function decide_all()

	load_all_data(io.open("data.dat", "rb"):read("a"))
	local out = io.open("ai.dat", "wb")

	for state,_ in pairs(graph) do

		local a,b,p = decide_state(state)
		out:write(string.pack(ai_fmt, state, a or 0, b or 0, p or 0))
	end

	out:close()
end

decide_all()
