defmodule TrialServer.Trial do

  require Logger

  @solution ~r/^([0-9a-fA-F]{32}):(-?[0-9]+)/

  def handle_packet({addr, port, "START"}) do
    Logger.debug("Received START from #{inspect addr}:#{inspect port}")
    {addr, port} |> new_trial()
  end

  def handle_packet({addr, port, data}) do
    Logger.debug("Received '#{data}' from #{inspect addr}:#{inspect port}")
    case Regex.run(@solution, data) do
      [_, uuid, solution] -> handle_solution(addr, port, uuid, String.to_integer(solution))
      _ -> nil
    end
  end

  defp handle_solution(addr, port, uuid, solution) do
    Logger.debug("Testing received solution '#{solution}' from uuid #{uuid}")
    TrialServer.Store.update_trial(uuid, solution)
    if TrialServer.Store.is_finished?(addr, port) do
      # pop from store |> total result
    else
      # new trial
    end
  end

  defp new_trial({addr, port}) do
    if TrialServer.Store.addr_in_store?(addr, port) do
      nil
    else
      {trial, uuid, solution} = generate_trial()
      TrialServer.Store.new_trial(addr, port, uuid, solution)
      {addr, port, trial}
    end
  end

  defp generate_trial() do
    u = TrialServer.UUID.uuid()
    n = :rand.uniform(4) + 2
    nums = for _ <- 1..n, do: :rand.uniform(200) + 1
    {ty, solution} = case :rand.uniform(3) do
      1 -> {"ADD",      Enum.sum(nums)}
      2 -> {"SUBTRACT", hd(nums) - Enum.sum(tl(nums))}
      3 -> {"MULTIPLY", Enum.reduce(nums, &(&1*&2))}
    end
    Logger.debug("Trial #{ty} #{inspect nums} with solution #{solution}")
    trial = ty <> ":" <> u <> ":" <> Enum.join(nums, ":")
    {trial, u, solution}
  end

end
