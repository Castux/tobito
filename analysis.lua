local tobito = require "tobito"

local function compute_graph()

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
	local next_queue = {}
	local treated = {}

	distances[s_int] = 0
	table.insert(to_treat, s_int)

	while #to_treat > 0 do

		local did_one = false

		for _,int in ipairs(to_treat) do
			for _,parent in ipairs(Graph[int].parents) do
				if not treated[parent] then
					distances[parent] = math.min(distances[parent] or math.maxinteger, 1 + distances[int])
					next_queue[parent] = true
				end
			end

			treated[int] = true
		end

		to_treat = {}
		for k in pairs(next_queue) do
			table.insert(to_treat, k)
		end
		next_queue = {}

	end

	return distances
end

local function compute_all_win_state_distances()

	local Graph = require "graph"
	local tmp_state = {}

	local count = 0

	for int,entry in pairs(Graph) do

		tobito.int_to_state(int, tmp_state)
		local w = tobito.state_winner(tmp_state)

		if w then
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

local function compute_heatmap()

	local Graph = require "graph"
	local tmp_state = {}

	local heat_top = {}
	local heat_bottom = {}

	local count = 0

	for int,entry in pairs(Graph) do

		tobito.int_to_state(int, tmp_state)
		local w = tobito.state_winner(tmp_state)

		if w then
			
			count = count + 1
			print(count)
			
			local heat = (w == tobito.Top) and heat_top or heat_bottom

			local distances = dofile("dist/" .. int .. ".lua")

			for s,d in pairs(distances) do

				if d == 0 then
					heat[s] = 65
				else
					heat[s] = (heat[s] or 0) + 1 / (d*d)
				end
			end
		end
	end

	return heat_top, heat_bottom
end

local function compute_sure_wins()
	
	local Graph = require "graph"
	
	local queue = {}
	local next_queue = {}
	local counts = {}
	local wins = {}
	
	local tmp_state = {}
	
	for int in pairs(Graph) do
		
		tobito.int_to_state(int, tmp_state)
		local w = tobito.state_winner(tmp_state)
		
		if w then
			wins[int] = w
			table.insert(queue, int)
		else
			counts[int] = #Graph[int].children
		end
	end
	
	while #queue > 0 do
		print(#queue)
		for _,int in ipairs(queue) do
			
			tobito.int_to_state(int, tmp_state)
			local player = tmp_state.next_player
			
			for _,parent in ipairs(Graph[int].parents) do
				if counts[parent] then
					
					if wins[int] and wins[int] ~= player then
						
						wins[parent] = wins[int]
						counts[parent] = nil
						table.insert(next_queue, parent)
						
					elseif wins[int] and wins[int] == player then
						
						counts[parent] = counts[parent] - 1
						if counts[parent] == 0 then
							wins[parent] = wins[int]
							counts[parent] = nil
							table.insert(next_queue, parent)
						end
					end
				
				end
			end
		end
		print("next", #next_queue)
		queue = next_queue
		next_queue = {}
	end
	
	return wins	
end


local function save_all_data()
	
	local pack_fmt = require("ai").pack_fmt
	local graph = require "graph"
	local top, bottom = compute_heatmap()
	local wins = compute_sure_wins()

	local fp = io.open("data.dat", "wb")
	
	local count = 0
	for k,_ in pairs(graph) do
		
		local t = math.floor((top[k] or 0) * 1000)
		local b = math.floor((bottom[k] or 0) * 1000)
		local w = wins[k] or tobito.Empty

		local packed = string.pack(pack_fmt, k, w, t, b)
		fp:write(packed)
		
		count = count + 1
	end

	fp:close()
	print("Wrote all data", count)
end

save_graph(compute_graph())
save_all_data()