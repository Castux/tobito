local tobito = require "tobito"

local function compute_graph()

	local states = {}
	local queue = {}
	local next_queue = {}

	table.insert(queue, tobito.state_to_int(tobito.start_state(tobito.Top)))
	table.insert(queue, tobito.state_to_int(tobito.start_state(tobito.Bottom)))

	local count = 0

	while #queue > 0 do
		for _,int in ipairs(queue) do
			
			if states[int] then
				goto skip
			end

			local state = tobito.int_to_state(int)
			local children = {}

			for m in tobito.valid_moves(state) do
				tobito.apply_move(m, state)
				child = tobito.state_to_int(state)

				table.insert(children, child)
				next_queue[child] = true
				
				tobito.int_to_state(int, state)
			end

			states[int] = { children = children, parents = {} }
			
			count = count + 1
			if count % 10000 == 0 then
				print(count, string.format("%.2f%%", count / 200000 * 100))
			end
			
			::skip::
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
	
	print("Graph computed", count)

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
		
		queue = next_queue
		next_queue = {}
	end
	
	return wins	
end


local function save_all_data()
	
	local pack_fmt = require("ai").pack_fmt
	local graph = require "graph"
	local wins = compute_sure_wins()

	local fp = io.open("data.dat", "wb")
	
	local count = 0
	for state in pairs(graph) do
		
		local w = wins[state]
		if w then
			local int = (w << 30) | state
			local packed = string.pack(pack_fmt, int)
			fp:write(packed)
			
			count = count + 1
		end
	end

	fp:close()
	print("Wrote all data", count)
end

save_graph(compute_graph())
save_all_data()