defmodule ManagerModule do
    use GenServer

    def start_link(noOfNodes,topology,algorithm) do
        args = [noOfNodes,topology,algorithm]
        IO.puts "Received at Manager: #{noOfNodes}\t#{topology}\t#{algorithm}"

        {:ok, superpid} = GenServer.start_link(__MODULE__,args, [noOfNodes])
        


        if algorithm == "gossip" || algorithm == "push-sum" do
            if topology == "2D" || topology == "imp2D" do
                val = round(Float.ceil(:math.sqrt(String.to_integer(noOfNodes))))
                noOfNodes = Integer.to_string(val*val)
                
            end
            IO.puts "No of nodes : #{noOfNodes}"
            pids = create_actors(algorithm, String.to_integer(noOfNodes),[],1)
            map_pids= for{v,k} <- pids 
            |> Enum.with_index, into: %{}, do: {v, k+1}
            start_node_index = :rand.uniform(Enum.count(pids)) -1
            IO.puts start_node_index
            IO.inspect Enum.at(pids, start_node_index)
            if algorithm == "gossip" do
                IO.puts " Sending starting gossip message to #{map_pids[Enum.at(pids, start_node_index)]}"
                GossipActor.receive_message(Enum.at(pids, start_node_index), topology, pids, superpid, map_pids, false)
            else
                IO.puts " Sending starting push-sum message to #{map_pids[Enum.at(pids, start_node_index)]}"
                PushSumActor.receive_message(Enum.at(pids, start_node_index), topology, pids, superpid, map_pids,[0,0], self)
            end


        else
            IO.puts "Entered wrong algorithm"
        end
        
        :timer.sleep(10000000)

        
        {:ok, pids}
       
    end



    def init(maxNodes) do
        no_of_nodes = 0
        start_time = System.system_time(:millisecond)
        state = [no_of_nodes, start_time, maxNodes]
        {:ok,  state}
    end

    def collect_convergence(process_id, sender_id,nodes_length, index, average, algorithm) do
        #IO.puts "In collect convergence"
        #IO.inspect sender_id
        GenServer.cast(process_id, {:collect_convergence, sender_id, nodes_length,index, average, algorithm})
    end

    def handle_cast({:collect_convergence, sender_id, nodes_length,index, average,algorithm}, state) do
        if algorithm == "gossip" do
            IO.puts "Node #{index} is converged"
        else
            IO.puts "Node #{index} is converged with average #{average} "
        end
        no_of_nodes = Enum.at(state, 0) 
        no_of_nodes = no_of_nodes + 1
        convergence_time = System.system_time(:millisecond) - Enum.at(state, 1)
            
        IO.puts "No of nodes #{no_of_nodes} have converged with time: #{convergence_time}"

        if no_of_nodes ==  nodes_length do
            convergence_time = System.system_time(:millisecond) - Enum.at(state, 1)
            IO.puts "All nodes converged in time : #{convergence_time} milliseconds"
        end
        time = Enum.at(state, 1)
        maxNodes = Enum.at(state, 2)
        
        state = [no_of_nodes, time, maxNodes]
        #IO.puts "#{Enum.at(state, 0)}"
        {:noreply, state}
    end

    def create_actors(algorithm, actors,pids,index) do
        cond do
        algorithm == "gossip" ->
            if actors == 1 do
                {:ok, pid} = GossipActor.start_link
                IO.inspect pid
                pids = Enum.concat([pid],pids)
            else
                {:ok, pid} = GossipActor.start_link
                pids = Enum.concat([pid],pids)
                IO.inspect pid
                create_actors(algorithm, actors-1,pids,index)
            end
        algorithm == "push-sum" ->
            if actors == 1 do
                {:ok, pid} = PushSumActor.start_link(index)
                IO.inspect pid
                pids = Enum.concat(pids,[pid])
            else
                val = [index]
                {:ok, pid} = PushSumActor.start_link(index)
                pids = Enum.concat(pids,[pid])
                IO.inspect pid
                create_actors(algorithm, actors-1,pids,index+1)
            end
        algorithm != "push-sum" && algorithm != "push-sum" ->
            IO.puts "Entered wrong algorithm"
        end
    end

end

