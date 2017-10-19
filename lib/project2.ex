defmodule Project2 do
  def main(args) do
     GossipSupervisor.start_link(Enum.at(args,0), Enum.at(args,1), Enum.at(args,2))
  end
  def hello do
    :world
  end
end
