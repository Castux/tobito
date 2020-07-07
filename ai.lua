local tobito = require "tobito"

local pack_fmt = "<L"

local function load_all_data(data_str)

	local win = {}
	local index = 1

	while index < #data_str do

		local int, next_index = string.unpack(pack_fmt, data_str, index)
		
		local w = int >> 30
		local state = int & 0x3fffffff

		win[state] = (w == tobito.Top) and 1 or (w == tobito.Bottom) and -1 or 0

		index = next_index
	end
	
	return win
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

local function state_score(int, player)
	
	local s = tobito.int_to_state(int)
	
	local sum = 0
	for cell = 0,tobito.MaxCell do
		if s[cell] == player then
			local row = cell // 3
			if player == tobito.Top then
				sum = sum + row
			else
				sum = sum + (4 - row)
			end
		end
	end
	
	return sum
end

local function decide_state(int, win, exclude)

	local state = tobito.int_to_state(int)
	local player = state.next_player
	local other = player == tobito.Top and tobito.Bottom or tobito.Top
	local m = (player == tobito.Top) and 1 or -1

	local acceptable_children = {}

	for move,child in tobito.valid_moves(state, exclude) do
		table.insert(acceptable_children, child)
	end

	local aggressive = max_for(acceptable_children, function(s)
		return 1000 * m * win[s] + 10 * state_score(s, player) - 1 * state_score(s, other)
	end)
	local balanced = max_for(acceptable_children, function(s)
		return 1000 * m * win[s] + 10 * state_score(s, player) - 10 * state_score(s, other)
	end)
	local prudent = max_for(acceptable_children, function(s)
		return 1000 * m * win[s] + 1 * state_score(s, player) - 10 * state_score(s, other)
	end)

	return aggressive, balanced, prudent
end

return
{
	pack_fmt = pack_fmt,
	decide_state = decide_state
}