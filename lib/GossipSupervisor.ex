defmodule GossipSupervisor do
    use Supervisor

    def start_link(noOfNodes, topology, algorithm) do
        args = [noOfNodes, topology, algorithm]
        Supervisor.start_link(__MODULE__,args)
    end
    def init(args) do
        ##IO.puts Enum.at(args,0) <>"\t"<> Enum.at(args,1)
        actors = 8 #String.to_integer(Enum.at(args,0))
        noOfNodes = Enum.at(args,0)
        topology = Enum.at(args,1)
        algorithm = Enum.at(args,2)
        #IO.puts "Received: #{noOfNodes}\t#{topology}\t#{algorithm}"
        
        ##k=[actors,zeros]
        children = [
           worker(ManagerModule,args)
        ]
        supervise(children, strategy: :one_for_one)
    end
end
