local Empty = 0
local Top = 1
local Bottom = 2

local MaxCell = 14

local function start_state()
	local s = {}

	for i = 0,MaxCell do
		s[i] = Empty
	end

	for i = 0,2 do
		s[i] = Top
	end

	for i = MaxCell - 2, MaxCell do
		s[i] = Bottom
	end

	s.next_player = Top
	s.start = true

	return s
end

local function draw_state(s)

	for i = 0,MaxCell do
		io.write(
			s[i] == Top and "T" or
			s[i] == Bottom and "B" or
			"."
		)
		if i % 3 == 2 then
			io.write "\n"
		end
	end
	print("Next:", s.next_player == Top and "Top" or "Bottom", s.start and "start" or "")
end

local function sort3(a,b,c)

	if a > b then a,b = b,a end
	if b > c then b,c = c,b end
	if a > b then a,b = b,a end

	return a,b,c
end

local function state_to_int_old(s)

	local i = 0

	for cell = 0,MaxCell do
		i = i | (s[cell] << (cell * 2))
	end

	i = i | (s.next_player << 30)
	i = i | ((s.start and 1 or 0) << 32)

	return i
end

local function int_to_state_old(i, s)

	s = s or {}

	for cell = 0,MaxCell do
		s[cell] = (i >> (cell * 2)) & 0x3
	end

	s.next_player = (i >> 30) & 0x3
	s.start = (i >> 32) == 1

	return s
end

local function state_to_int(s)

	local i = 0
	local top_index = 0
	local bottom_index = 3

	for cell = 0,MaxCell do
		if s[cell] == Top then
			i = i | (cell << (top_index * 4))
			top_index = top_index + 1

		elseif s[cell] == Bottom then
			i = i | (cell << (bottom_index * 4))
			bottom_index = bottom_index + 1
		end
	end

	i = i | (s.next_player << 24)
	i = i | ((s.start and 1 or 0) << 26)

	return i
end

local function int_to_state(int, s)

	s = s or {}

	for cell = 0,MaxCell do
		s[cell] = Empty
	end

	for i = 0,5 do
		local cell = (int >> (i * 4)) & 0xf
		s[cell] = (i < 3) and Top or Bottom
	end

	s.next_player = (int >> 24) & 0x3
	s.start = (int >> 26) == 1

	return s
end

local function state_winner(s)

	if s.start then
		return nil
	end

	-- Invasion

	if s[0] == Bottom and s[1] == Bottom and s[2] == Bottom then
		return Bottom, "invasion"
	elseif s[12] == Top and s[13] == Top and s[14] == Top then
		return Top, "invasion"
	end

	-- Passivity

	if s.next_player == Top and s[12] ~= Empty and s[13] ~= Empty and s[14] ~= Empty then
		return Top, "passivity"
	elseif s.next_player == Bottom and s[0] ~= Empty and s[1] ~= Empty and s[2] ~= Empty then
		return Bottom, "passivity"
	end

	return nil
end

local function moves_from_cell(cell)

	local row,col = cell // 3, cell % 3

	local dirs = {}

	for dr = -1,1 do
		for dc = -1,1 do
			if not(dr == 0 and dc == 0) then

				local dir = {}

				for i = 1,5 do
					local r,c = row + i * dr, col + i * dc
					if r < 0 or r > 4 or c < 0 or c > 2 then
						break
					end
					table.insert(dir, r * 3 + c)
				end

				if #dir > 0 then
					table.insert(dirs, dir)
				end
			end
		end
	end

	return dirs
end

local function precompute_moves()

	local moves = {}
	for cell = 0,MaxCell do
		moves[cell] = moves_from_cell(cell)
	end
	return moves
end

local function relocations(s, num, avoid)

	local res = {}

	local function rec(level)

		if level > num then
			coroutine.yield(res)
			return
		end

		for cell = (res[level-1] or -1) + 1, MaxCell do
			if s[cell] == Empty and cell ~= avoid then
				res[level] = cell

				if level == num then
					coroutine.yield(res)
				else
					rec(level + 1)
				end
			end
		end
	end

	return coroutine.wrap(function() rec(1) end)
end

local function movable_pawn(s, cell)

	if s[cell] == Top then
		return cell < 12
	elseif s[cell] == Bottom then
		return cell > 2
	end

	error "Not a pawn"
end

local function active_pawn(s, cell)
	if s.next_player ~= s[cell] then
		return false
	end

	return movable_pawn(s, cell)
end

local function active_pawns(s)
	return coroutine.wrap(function()
			for cell = 0,MaxCell do
				if active_pawn(s, cell) then
					coroutine.yield(cell)
				end
			end
		end)
end

local function moves_from_cell(s, cell)
	
	local Moves = precompute_moves()

	return coroutine.wrap(function()
			for _,dir in ipairs(Moves[cell]) do

				local jumped = {}

				for i,dest in ipairs(dir) do
					if s[dest] == Empty then

						for _,j in ipairs(jumped) do
							if not movable_pawn(s, j) then
								goto skip
							end
						end

						for reloc in relocations(s, #jumped, dest) do
							local move = {cell, dest}

							for i = 1,#jumped do
								table.insert(move, jumped[i])
								table.insert(move, reloc[i])
							end

							coroutine.yield(move)
						end

						::skip::

						break

					elseif s[dest] ~= s.next_player then
						table.insert(jumped, dest)
					end
				end
			end
		end)
end

local function valid_moves(s)
	return coroutine.wrap(function()

			local w = state_winner(s)
			if w then
				return
			end

			for cell in active_pawns(s) do
				for move in moves_from_cell(s, cell) do
					coroutine.yield(move)
				end
			end
		end)
end

local function apply_move(s, m)

	for i = 1,#m,2 do
		s[m[i+1]] = s[m[i]]
		s[m[i]] = Empty
	end

	s.next_player = s.next_player == Top and Bottom or Top
	s.start = false
end


local function pick_n(arr, n)

	local picked, left = {},arr

	local function rec(start, n)
		if n == 0 then
			coroutine.yield(picked)
			return
		end

		for i = start,#left do

			table.insert(picked, table.remove(left, i))
			rec(i, n-1)
			table.insert(left, i, table.remove(picked))

		end
	end

	return coroutine.wrap(function() rec(1, n) end)
end

local function all_states()

	local states = {}

	local cells = {}
	for i = 0,MaxCell do
		table.insert(cells, i)
	end

	for top in pick_n(cells, 3) do
		for bottom in pick_n(cells, 3) do		-- trick: cells is modified by pick_n and contains only the ones left
			for player = Top,Bottom do

				local int = 0
				for i,t in ipairs(top) do
					int = int | (t << ((i - 1) * 4))
				end
				for i,b in ipairs(bottom) do
					int = int | (b << ((i + 2) * 4))
				end

				int = int | (player << 24)

				table.insert(states, int)
			end
		end
	end

	local ss = start_state()
	table.insert(states, state_to_int(ss))
	ss.next_player = Bottom
	table.insert(states, state_to_int(ss))

	return states
end

return
{
	Top = Top,
	Bottom = Bottom,
	Empty = Empty,
	MaxCell = MaxCell,

	state_to_int = state_to_int,
	int_to_state = int_to_state,
	start_state = start_state,
	draw_state = draw_state,
	
	valid_moves = valid_moves,
	apply_move = apply_move,
	
	state_winner = state_winner
}
