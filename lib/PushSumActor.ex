defmodule PushSumActor do
        use GenServer

        def start_link(index) do
            GenServer.start_link(__MODULE__,index)
            #WorkerModule.get_bitcoins(pid, no_of_zeros)
        end

        def init(index) do
            sum = index
            w = 1
            no_change = 0
            state = [sum,w, no_change]
            {:ok,state} 
        end

        def receive_message(process_id,topology, pids, superpid, map_pids,sum_w, self) do
            GenServer.cast(process_id,{:receive_message, topology, pids, superpid, process_id,map_pids,sum_w, self})
        end

        def handle_cast({:receive_message, topology, pids, superpid, process_id,map_pids, sum_w, self}, state) do
            sum = Enum.at(state, 0)
            w = Enum.at(state, 1)
            #IO.puts "Here #{w} AND #{Enum.at(sum_w,1)}"
             if w > 0 do
             #   IO.puts "Also here"
                ratio = sum/ w

                no_change = Enum.at(state, 2)
                if no_change < 3 do
                    
                      # IO.puts "Received"
                        new_sum = Enum.at(state,0) + Enum.at(sum_w,0)
                        new_w = Enum.at(state,1) + Enum.at(sum_w,1)
                        if new_w > 0 do
                           # IO.puts "Greater than zero"

                            new_ratio = new_sum/ new_w
                        
                            diff_ratios = new_ratio - ratio
                            #IO.puts diff_ratios
                            no_change = Enum.at(state, 2)
                        
                            if abs(Float.round(diff_ratios,9)) < 10.0e-4 do
                                no_change = no_change + 1
                                #IO.puts "No Change: #{no_change}"
                            else
                                no_change = 0
                            end

                            #if no_change <= 3 do
                                new_sum = new_sum/2
                                new_w = new_w/2 
                                sum_w = [new_sum, new_w]
                                state = [new_sum, new_w , no_change]
                                PushSumActor.send_next_available_pid(topology, pids, process_id, map_pids, state, superpid,sum_w)
                                if no_change == 3 do
                                  # IO.puts "Converging"
                                    new_ratio = Float.round(new_ratio, 1)
                                    ManagerModule.collect_convergence(superpid, process_id,Dict.size(map_pids),map_pids[process_id], new_ratio,"push-sum")
                                end
                            #end
                        end 
                    #else
                       # IO.puts "Self In here"
                    #    PushSumActor.send_next_available_pid(topology, pids, process_id, map_pids, state, superpid,sum_w) 
                    #end
                end
            end
            {:noreply, state}
        end

        def send_next_available_pid(topology, pids, process_id, map_pids, state, superpid,sum_w) do
            neighbours = []
            #IO.puts "Send next"
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
            pid = find_rand_neighbour(process_id,neighbours)
            PushSumActor.receive_message(pid, topology, pids, superpid, map_pids,sum_w, false)
            #PushSumActor.send_next_available_pid(topology, pids, process_id, map_pids, state, superpid,sum_w)
            PushSumActor.receive_message(process_id, topology, pids, superpid, map_pids,sum_w, true)
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
