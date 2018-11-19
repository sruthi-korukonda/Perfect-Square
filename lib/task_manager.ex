defmodule DOSPRJ.TaskManager do
  use GenServer
  @moduledoc """
  Distributes the list of 1 to n in seperate windows of size k.
  Computes the aggregate of the perfect squares in seperate process.
  Checks whether the aggregate is a perfect square.
  """
  ## Client API

  @doc """
  Starts the GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Finds the perfect square sequence for the given input.
  Returns `{:ok, list}` if sequence exists.
  Otherwise returns empty list.
  """
  def execute(server, args) do
    GenServer.call(server, {:compute, args}, 800000)
  end


  ## Server Callbacks

  @doc """
  Initiating the state of GenServer with empty tuple
  """
  def init(:ok) do
    {:ok,{}}
  end

  @doc """
  Combines the output of the tasks
  """
  defp combineTaskOutput(task, acc) do
    seqList =Task.await(task)
    if(seqList != []) do
      [ seqList | acc]
    else
      acc
    end
  end

  @doc """
  Server side function to handle the perfect square request.
  Returns `{out, state}`
  """
  def handle_call({:compute, args}, _from, state) do
    n = List.first(args)
    k = List.last(args)
    route = routingTable()
    taskList = splitTask(n,k,1,[],route)
    out = Enum.reduce(taskList, [], fn task,acc ->  combineTaskOutput(task, acc) end)
    {:reply, out, state}
  end

  @doc """
  End of recursion when start is greater than n
  Returns '[tasklist]' which is the list of tasks which can be awaited to get the output
  """
  defp splitTask(n, _, start, tasklist, _ ) when start >n do
    tasklist
  end

  @doc """
  Starting a seperate process for each window of k size from start,start+1,start+2...
  """
  defp splitTask(n, k, start, tasklist, route) do
    last = start + k-1
    window = Enum.to_list start..last
    task = Task.Supervisor.async({DOSPRJ.TaskSupervisor, getNode(route, start)}, fn -> checkPerfrectSq?(window) end)
    tasklist = [task | tasklist]
    splitTask(n, k, (start + 1),tasklist, route)
  end

  @doc """
  Checking whether the aggregate of squares of sequence of integers is perfect square
  """
  defp checkPerfrectSq?(list) do
    if calculateSquare(list) |>  is_sqrt_natural? == true do
      list
    else
      []
    end
  end

  @doc """
  Checks whether the given number is a perfect square
  """
  defp is_sqrt_natural?(n) when is_integer(n) do
    :math.sqrt(n) |> :erlang.trunc |> :math.pow(2) == n
  end

  defp is_sqrt_natural?(_n) do
    false
  end

  @doc """
  Aggregates the squares of sequence of integers
  """
  defp calculateSquare(list) do
    Enum.map(list, fn x -> x*x end) |> Enum.sum
  end

  defp routingTable do
    # Return node list from config file
    Application.fetch_env!(:DOSPRJ, :routing_table)
  end

  defp getNode(route,index) do
    # return nodes present at given index
    if tuple_size(route) != 0 do
      elem(route,rem(index, tuple_size(route)))
    else
      # if no nodes are mentioned in routing table it returns the current node
      node()
    end
  end
end
