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

local function save_graph(graph)

	local fp = io.open("graph.lua", "w")
	fp:write "return {\n"
	for k,v in pairs(graph) do
		fp:write(string.format("[%d] = { children = {%s}, parents = {%s} },\n", k, table.concat(v.children, ","), table.concat(v.parents, ",")))
	end
	fp:write "}"
	fp:close()
end

save_graph(compute_graph())

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
	local Graph = require "graph"

	-- Initialize

	for int,entry in pairs(Graph) do

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

		for _,parent in ipairs(Graph[int].parents) do
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

local function distances_from_state(s_int)

	local Graph = require "graph"

	local distances = {}
	local to_treat = {}
	local treated = {}

	distances[s_int] = 0
	to_treat[s_int] = true

	while true do

		local did_one = false

		for k in pairs(to_treat) do
			for _,parent in ipairs(Graph[k].parents) do
				if not treated[parent] then
					distances[parent] = math.min(distances[parent] or math.maxinteger, 1 + distances[k])
					to_treat[parent] = true
				end
			end

			to_treat[k] = nil
			treated[k] = true
			did_one = true
		end

		if not did_one then break end
	end

	return distances
end

local function compute_all_win_state_distances()

	local Graph = require "graph"
	local tmp_state = {}

	local count = 0

	for int,entry in pairs(Graph) do

		int_to_state(int, tmp_state)
		local w,kind = state_winner(tmp_state)

		if kind == "invasion" then

			count = count + 1
			print(count)

			local fp = io.open("dist/" .. int .. ".lua", "w")
			fp:write "return {\n"

			for state,distance in pairs(distances_from_state(int)) do
				fp:write(string.format("[%d] = %d,\n", state, distance))
			end

			fp:write "}"
			fp:close()

		end
	end

end

--compute_all_win_state_distances()

local function compute_heatmap()

	local Graph = require "graph"
	local tmp_state = {}

	local heat = {}

	local count = 0

	for int,entry in pairs(Graph) do

		count = count + 1
		print(count)

		int_to_state(int, tmp_state)
		local w,kind = state_winner(tmp_state)

		if kind == "invasion" then

			local distances = dofile("dist/" .. int .. ".lua")

			for s,d in pairs(distances) do

				if d == 0 then
					heat[s] = (w == Top and 1e6 or -1e6)
				else
					heat[s] = (heat[s] or 0) + (w == Top and 1 or -1) * 1 / (d*d)
				end
			end
		end
	end

	return heat
end

local function save_heatmap(heat)

	local fp = io.open("heatmap.lua", "w")
	fp:write "return {\n"

	for k,v in pairs(heat) do
		fp:write(string.format("[%d] = %f,\n", k, v))
	end

	fp:write "}"
	fp:close()
end

save_heatmap(compute_heatmap())

local function show_heatmap()

	local heat = dofile "heatmap.lua"

	local list = {}
	for k,v in pairs(heat) do
		table.insert(list, k)
	end

	table.sort(list, function(a,b)
		return heat[a] < heat[b]
	end)

	local tmp_state = {}

	for _,v in pairs(list) do

		print "====="
		int_to_state(v, tmp_state)
		draw_state(tmp_state)
		print(heat[v])
	end
end

--show_heatmap()

local function decide_state(s)

	local heat = require "heatmap"
	local graph = require "graph"

	local int = state_to_int(s)
	draw_state(s)

	for _,child in ipairs(graph[int].children) do
		print "==="
		draw_state(int_to_state(child))
		print(heat[child])
	end

end

--decide_state(start_state())

return
{
	Top = Top,
	Bottom = Bottom,
	Empty = Empty,
	MaxCell = MaxCell,

	state_to_int = state_to_int
}
