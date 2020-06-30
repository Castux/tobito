local tobito = require "tobito"

local function compute_graph2()

	local states = {}
	local queue = {}
	local next_queue = {}

	local ss = tobito.start_state()
	ss.next_player = tobito.Top
	table.insert(queue, tobito.state_to_int(ss))
	ss.next_player = tobito.Bottom
	table.insert(queue, tobito.state_to_int(ss))

	while #queue > 0 do
		print (#queue)
		for _,int in ipairs(queue) do
			
			local state = tobito.int_to_state(int)
			local children = {}

			for m in tobito.valid_moves(state) do
				tobito.apply_move(m, state)
				child = tobito.state_to_int(state)
				
				table.insert(children, child)

				if not states[child] then
					next_queue[child] = true
				end
				
				tobito.int_to_state(int, state)
			end
			
			states[int] = { children = children, parents = {} }
		end

		queue = {}
		for child in pairs(next_queue) do
			table.insert(queue, child)
		end
		next_queue = {}
	end
	
	for int,entry in pairs(states) do
		for _,child in ipairs(entry.children) do
			table.insert(states[child].parents, int)
		end
	end
	
	return states
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

		tobito.int_to_state(int, tmp_state)
		local w,kind = tobito.state_winner(tmp_state)

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

local function compute_heatmap()

	local Graph = require "graph"
	local tmp_state = {}

	local heat = {}

	local count = 0

	for int,entry in pairs(Graph) do

		count = count + 1
		print(count)

		tobito.int_to_state(int, tmp_state)
		local w,kind = tobito.state_winner(tmp_state)

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
		tobito.int_to_state(v, tmp_state)
		tobito.draw_state(tmp_state)
		print(heat[v])
	end
end

local function decide_state(s)

	local heat = require "heatmap"
	local graph = require "graph"

	local int = state_to_int(s)
	tobito.draw_state(s)

	for _,child in ipairs(graph[int].children) do
		print "==="
		tobito.draw_state(tobito.int_to_state(child))
		print(heat[child])
	end

end

save_graph(compute_graph())
--compute_all_win_state_distances()
--save_heatmap(compute_heatmap())
--show_heatmap()
--decide_state(start_state())