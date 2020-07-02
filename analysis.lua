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
	local results = {}
	
	local tmp_state = {}
	
	-- Init queue
	
	for int,_ in pairs(Graph) do
		
		tobito.int_to_state(int, tmp_state)
		local w = tobito.state_winner(tmp_state)
		
		if w == tobito.Top then
			results[int] = 1
		elseif w == tobito.Bottom then
			results[int] = -1
		end
		
		for _,parent in ipairs(Graph[int].parents) do
			queue[parent] = true
		end
	end
	
	-- Process
	
	while next(queue) do
		for int,_ in pairs(queue) do
			
			local player = (int >> 24) & 0x3
			
			local fun,best
			if player == tobito.Top then
				fun = math.max
				best = -10
			else
				fun = math.min
				best = 10
			end
			
			for _,child in ipairs(Graph[int].children) do
				best = fun(best, results[child] or 0)
			end
			
			results[int] = best
			
			for _,parent in ipairs(Graph[int].parents) do
				if not results[parent] then
					next_queue[parent] = true
				end
			end
		end
		
		queue = next_queue
		next_queue = {}
	end
	
	return results
end

local pack_fmt = "LbHH"

local function save_all_data()
	
	local top, bottom = compute_heatmap()
	local wins = compute_sure_wins()

	local fp = io.open("data.dat", "wb")
	
	for k,_ in pairs(wins) do
		
		local t = math.floor((top[k] or 0) * 1000)
		local b = math.floor((bottom[k] or 0) * 1000)
		local w = wins[k]
		
		local packed = string.pack(pack_fmt, k, w, t, b)
		fp:write(packed)
	end

	fp:close()
end

local function load_all_data()
	
	local fp = io.open("data.dat", "rb")
	local len = string.packsize(pack_fmt)
	
	local top, bottom, win = {}, {}, {}
	
	for str in fp:lines(len) do
		local state, w, t, b = string.unpack(pack_fmt, str)
	
		win[state] = w
		top[state] = t
		bottom[state] = b
	end
	
	fp:close()
	
	return win, top, bottom
end

local win, top, bottom = load_all_data()

for k,v in pairs(win) do
	if v == 1 then
		print(tobito.draw_state(k))
	end
end
