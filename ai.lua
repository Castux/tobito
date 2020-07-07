local tobito = require "tobito"

local pack_fmt = "LLLL"

local function load_all_data(data_str)

	local top, bottom, win = {},{},{}
	local index = 1

	while index < #data_str do

		local state, w, t, b, next_index = string.unpack(pack_fmt, data_str, index)

		win[state] = (w == tobito.Top) and 1 or (w == tobito.Bottom) and -1 or 0
		top[state] = t
		bottom[state] = b

		index = next_index
	end
	
	return win, top, bottom
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

local function decide_state(int, win, top, bottom)

	local state = tobito.int_to_state(int)
	local player = state.next_player
	local m = (player == tobito.Top) and 1 or -1

	local win_value = nil
	local acceptable_children = {}

	for move,child in tobito.valid_moves(state) do
		table.insert(acceptable_children, child)
	end

	local aggressive = max_for(acceptable_children, function(s) return m * (1e6 * win[s] + top[s]) end)
	local balanced = max_for(acceptable_children, function(s) return m * (1e6 * win[s] + top[s] - bottom[s]) end)
	local prudent = max_for(acceptable_children, function(s) return m * (1e6 * win[s] - bottom[s]) end)

	return aggressive, balanced, prudent
end

return
{
	pack_fmt = pack_fmt,
	decide_state = decide_state
}