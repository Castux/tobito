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
	print("Next:", s.next_player == Top and "Top" or "Bottom")
end

local function state_to_int(s)

	local i = 0

	for cell = 0,MaxCell do
		i = i | (s[cell] << (cell * 2))
	end

	i = i | (s.next_player << 30)

	return i
end

local function int_to_state(i, s)

	s = s or {}

	for cell = 0,MaxCell do
		s[cell] = (i >> (cell * 2)) & 0x3
	end

	s.next_player = (i >> 30) & 0x3

	return s
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

local Moves = precompute_moves()

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

local function active_pawn(s, cell)
	if s.next_player ~= s[cell] then
		return false
	end

	if s.next_player == Top then
		return cell < 12
	else
		return cell > 2
	end
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

	return coroutine.wrap(function()
			for _,dir in ipairs(Moves[cell]) do

				local jumped = {}

				for i,dest in ipairs(dir) do
					if s[dest] == Empty then

						for reloc in relocations(s, #jumped, dest) do
							local move = {cell, dest}

							for i = 1,#jumped do
								table.insert(move, jumped[i])
								table.insert(move, reloc[i])
							end

							coroutine.yield(move)
						end

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

				local i = 0
				for _,t in ipairs(top) do
					i = i | (Top << (t * 2))
				end
				for _,b in ipairs(bottom) do
					i = i | (Bottom << (b * 2))
				end

				i = i | (player << 30)

				table.insert(states, i)
			end
		end
	end

	return states
end

local function compute_graph()

	local graph = {}
	local s = {}

	for i,int in ipairs(all_states()) do
		local children = {}

		int_to_state(int, s)

		for m in valid_moves(s) do
			apply_move(s, m)
			table.insert(children, state_to_int(s))
			int_to_state(int, s)
		end

		graph[int] = {children = children, parents = {}}

		if i % 10000 == 0 then
			print(i)
		end
	end

	for int,entry in pairs(graph) do
		for _,child in ipairs(entry.children) do
			table.insert(graph[child].parents, int)
		end
	end

	return graph
end

local function save_values(values)

	local fp = io.open("values.lua", "w")
	fp:write "return {\n"
	for k,v in pairs(values) do
		fp:write(string.format("[%d] = { children = {%s}, parents = {%s} },\n", k, table.concat(v.children, ","), table.concat(v.parents, ",")))
	end
	fp:write "}"
	fp:close()
end

--save_values(compute_graph())

--[[ Backwards analysis ]]

local Win = 1
local Loss = 2
local Count = 3

local function encode(kind, amount)
	return (kind << 16) | amount
end

local function decode(value)
	return value >> 16, value & 0xffff
end

local function win_state(s)

	if s[0] == Bottom and s[1] == Bottom and s[2] == Bottom then

		return s.next_player == Bottom and Win or Loss

	elseif s[12] == Top and s[13] == Top and s[14] == Top then

		return s.next_player == Top and Win or Loss

	end

end

local function new_queue()

	local _start, _end = 1,0
	local q = {}

	q.push = function(v)
		_end = _end + 1
		q[_end] = v
	end

	q.pop = function()
		if _start > _end then
			return nil
		else
			_start = _start + 1
			return q[_start - 1]
		end
	end

	return q
end

local function analysis()

	local R = {}
	local tmp_state = {}
	local queue = new_queue()
	local Values = require "values"

	-- Initialize

	for int,entry in pairs(Values) do

		int_to_state(int, tmp_state)
		local w = win_state(tmp_state)

		if w then
			R[int] = encode(w, 0)
			queue.push(int)
		else
			R[int] = encode(Count, #entry.children)
		end
	end

	-- Process

	while true do
		local int = queue.pop()
		if not int then
			break
		end

		local current_kind,current_value = decode(R[int])

		for _,parent in ipairs(Values[int].parents) do
			local parent_kind, parent_amount = decode(R[parent])

			if parent_kind == Count then

				if current_kind == Win then

					parent_amount = parent_amount - 1
					R[parent] = encode(Count, parent_amount)

					if parent_amount == 0 then		-- all children of this parent were Wins, so it's a loss
						R[parent] = encode(Loss, 1 + current_value)
						queue.push(parent)
					end


				else -- Loss: at least one child (this one) of this parent is a Loss, so it's a win

					R[parent] = encode(Win, 1 + current_value)
					queue.push(parent)

				end

			end
		end
	end

	return R
end

local R = analysis()
local counts = {[Loss] = 0, [Win] = 0, [Count] = 0}
for k,v in pairs(R) do
	local kind, amount = decode(v)
	counts[kind] = counts[kind] + 1
end

for k,v in pairs(counts) do
	print(k,v / 200200)
end