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

	return s
end

local function draw_state(s)

	if type(s) == "number" then
		s = int_to_state(s)
	end

	local res = {}
	for i = 0,MaxCell do
		table.insert(res,
			s[i] == Top and "T" or
			s[i] == Bottom and "B" or
			"."
		)
		if i % 3 == 2 then
			table.insert(res, "\n")
		end
	end
	table.insert(res, "Next: " .. (s.next_player == Top and "Top" or "Bottom"))

	return table.concat(res)
end

local function state_winner(s)

	if s[0] == Bottom and s[1] == Bottom and s[2] == Bottom then
		return Bottom
	elseif s[12] == Top and s[13] == Top and s[14] == Top then
		return Top
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

local function home_row_full(s, player)

	return (player == Top and s[0] ~= Empty and s[1] ~= Empty and s[2] ~= Empty) or
	(player == Bottom and s[12] ~= Empty and s[13] ~= Empty and s[14] ~= Empty)
end

local function apply_move(s, m)

	for i = 1,#m,2 do
		s[m[i+1]] = s[m[i]]
		s[m[i]] = Empty
	end

	s.next_player = s.next_player == Top and Bottom or Top
end

local function valid_moves(s)
	return coroutine.wrap(function()

			local int = state_to_int(s)
			local player = s.next_player

			local w = state_winner(s)
			if w then
				return
			end

			for cell in active_pawns(s) do
				for move in moves_from_cell(s, cell) do

					-- Try applying move to check for passivity

					apply_move(s, move)
					if not home_row_full(s, player) then
						coroutine.yield(move)
					end

					int_to_state(int, s)
				end
			end
		end)
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
