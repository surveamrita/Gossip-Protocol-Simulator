
defmodule GossipActor do
        use GenServer

        def start_link do
            #IO.puts "In Gossip"  
            GenServer.start_link(__MODULE__,[])
            #WorkerModule.get_bitcoins(pid, no_of_zeros)
        end

        def init(args) do
            no_of_rumours = 0
            state = [no_of_rumours]
            {:ok,  state}
        end

        def receive_message(process_id,topology, pids, superpid, map_pids, self) do
            GenServer.cast(process_id,{:receive_message, topology, pids, superpid, process_id, map_pids, self})
        end
        
        def handle_cast({:receive_message, topology, pids, superpid, process_id, map_pids, self}, state) do
            no_of_rumours = Enum.at(state, 0)
              
            if no_of_rumours < 10 do
                    
                if !self do
                    no_of_rumours = no_of_rumours+1
                    if no_of_rumours == 10 do
                        
                        {:ok,index} = Map.fetch(map_pids,process_id)
                        #IO.puts "Node at index #{index} has converged "
                        GossipActor.send_next_available_pid(topology, pids, process_id, map_pids, state, superpid)
                        #IO.puts "Converging"
                        ManagerModule.collect_convergence(superpid, process_id,Dict.size(map_pids),  index, 0, "gossip")
                    else
                        GossipActor.send_next_available_pid(topology, pids, process_id, map_pids, state, superpid)
                    end
                else
                    GossipActor.send_next_available_pid(topology, pids, process_id, map_pids, state, superpid)
                end
            end
           state = [no_of_rumours]
            {:noreply, state}
        end

        def send_next_available_pid(topology, pids, process_id, map_pids, state, superpid) do
            neighbours = []
            {:ok, index} = Map.fetch(map_pids,process_id)
            #IO.puts "Working in Node #{index}"           
            cond do
                topology == "2D" ->
                    neighbours = find_2D_neighbours(process_id, map_pids, pids)
                topology == "imp2D" ->
                    neighbours = find_imp2D_neighbours(process_id, map_pids, pids)
                topology == "line" ->
                    neighbours = find_line_neighbours(process_id, map_pids, pids)
                topology == "full" ->
                    neighbours = find_full_neighbours(process_id, map_pids, pids)
            end
            no_of_rumours = Enum.at(state, 0)
            if no_of_rumours <= 10 do
                pid = find_rand_neighbour(process_id,neighbours)
                GossipActor.receive_message(pid, topology, pids, superpid, map_pids, false)
                GossipActor.receive_message(process_id, topology, pids, superpid, map_pids, true)
                
           end
        end

        def delete_neighbours_from_full_list(neighbours, temp_pids) do
            cond do
                Enum.count(neighbours) == 0 ->
                    temp_pids
                Enum.count(neighbours) >= 1 ->
                    n_pid =  Enum.at(neighbours, 0)
                    temp_pids  = List.delete(temp_pids, n_pid)
                    neighbours = List.delete(neighbours, n_pid)
                    delete_neighbours_from_full_list(neighbours, temp_pids)
            end    
        end

        def find_imp2D_neighbours(process_id, map_pids, pids) do
            neighbours = find_2D_neighbours(process_id, map_pids, pids)
            temp_pids = pids
            temp_pids = List.delete(temp_pids, process_id)
            temp_pids = delete_neighbours_from_full_list(neighbours, temp_pids) 
            rand_node_index = :rand.uniform(Enum.count(temp_pids)) -1
            pid = Enum.at(temp_pids, rand_node_index)
            if pid != nil && pid != process_id do
                neighbours = Enum.concat(neighbours, [pid])
            end
            #IO.puts "All imp2d neighbours"
            #IO.inspect neighbours
            neighbours
        end

        def find_2D_neighbours(process_id, map_pids, pids) do
            neighbours = []
            root = round(:math.sqrt(Dict.size(map_pids)))
            {:ok,index} = Map.fetch(map_pids,process_id)
            cond do
                rem(index, root) == 0 -> 
             #       IO.puts "Index : #{index} with root : #{root} and "
                    if index - 1 >= 1 do
                        pid = Enum.at(pids,index - 2)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                    if index - root >= 1 do 
                        pid = Enum.at(pids,index - root - 1)
                        if pid != nil do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                    if index + root <= Dict.size(map_pids) do
                        pid = Enum.at(pids, index + root - 1)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                rem((index - 1), root) == 0 ->
                    if index + 1 <= Dict.size(map_pids) do
                        pid = Enum.at(pids,index)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                    if index - root >= 0 do
                        pid = Enum.at(pids,index - root - 1)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                    if index + root <= Dict.size(map_pids) do
                        pid = Enum.at(pids, index + root - 1)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                true ->
                    if index - 1 >= 1 do
                        pid = Enum.at(pids,index - 2)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                    if index + 1 <= Dict.size(map_pids) do
                        pid = Enum.at(pids,index)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                    if index - root >= 1 do
                        pid = Enum.at(pids,index - root - 1)
                        if pid != nil  do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end 
                    if index + root <= Dict.size(map_pids) do
                        pid = Enum.at(pids, index + root - 1)
                        if pid != nil   do
                            neighbours = Enum.concat(neighbours, [pid])
                        end
                    end
                end
            #IO.puts "These are the neighbours for 2D only"
            #IO.inspect neighbours
            neighbours
        end

        def find_rand_neighbour(process_id, pids) do
            next_node_index = :rand.uniform(Enum.count(pids)) -1
            Enum.at(pids, next_node_index)
        end

        def find_line_neighbours(process_id, map_pids, pids) do
            neighbours = []
            {:ok, index} = Map.fetch(map_pids, process_id)
            #IO.puts "Entered node #{index}"
            if index - 1 > 0 do
                pid = Enum.at(pids, index-2)
                if pid != nil  do
                    neighbours = Enum.concat(neighbours, [pid])
                end
                left_index = index - 1
             #   IO.puts " Neighbours of #{index} is #{left_index}"
            end
            if index + 1 <= Dict.size(map_pids) do
                pid = Enum.at(pids, index)
                if pid != nil   do
                    neighbours = Enum.concat(neighbours, [pid])
                end
                right_index = index + 1
                #IO.puts " Neighbours of #{index} is #{right_index}"
            end
            neighbours
        end

        def find_full_neighbours(process_id,map_pids, pids) do
            temp_pids = pids
            temp_pids = List.delete(temp_pids, process_id)
        end


       
end
      #Bitcoin.start([3])
