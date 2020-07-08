local tobito = require "tobito"

local function compute_graph()

	local states = {}
	local queue = {}
	local next_queue = {}

	table.insert(queue, tobito.state_to_int(tobito.start_state(tobito.Top)))
	table.insert(queue, tobito.state_to_int(tobito.start_state(tobito.Bottom)))
	table.insert(queue, tobito.state_to_int(tobito.start_state(tobito.Top, true)))
	table.insert(queue, tobito.state_to_int(tobito.start_state(tobito.Bottom, true)))
	
	local tmp_state = {}
	local count = 0

	while #queue > 0 do
		
		for _,int in ipairs(queue) do
			
			if states[int] and states[int].children_count then
				goto skip
			end

			tobito.int_to_state(int, tmp_state)
			local children_count = 0

			for move,child in tobito.valid_moves(tmp_state) do
				
				children_count = children_count + 1
				
				states[child] = states[child] or {}
				table.insert(states[child], int)

				next_queue[child] = true
			end

			states[int] = states[int] or {}
			states[int].children_count = children_count
		
			count = count + 1
			if count % 10000 == 0 then
				print(count, string.format("%.2f%%", count / 1824973 * 100))
			end
			
			::skip::
		end

		queue = {}
		for child in pairs(next_queue) do
			table.insert(queue, child)
		end
		next_queue = {}
	end
	
	print("Total", count)
	return states
end

local function save_graph(graph)
	
	print "Writing graph.lua"
	local count = 0
	
	local fp = io.open("graph.lua", "w")
	fp:write "return {\n"
	for k,v in pairs(graph) do
		count = count + 1
		fp:write(string.format("[%d] = { children_count = %d, %s },\n", k, v.children_count or 0, table.concat(v, ",")))
	end
	fp:write "}"
	fp:close()
	
	print("Wrote", count)
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
			counts[int] = Graph.children_count
		end
	end
	
	local c = 0
	
	while #queue > 0 do
		
		for _,int in ipairs(queue) do
			
			c = c + 1
			if c % 1000 == 0 then
				print(c)
			end
			
			tobito.int_to_state(int, tmp_state)
			local player = tmp_state.next_player
			
			for _,parent in ipairs(Graph[int]) do
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
		
		local w = wins[state] or tobito.Empty
		local int = (w << 30) | state
		local packed = string.pack(pack_fmt, int)
		fp:write(packed)
		
		count = count + 1
	end

	fp:close()
	print("Wrote all data", count)
end

save_graph(compute_graph())
save_all_data()