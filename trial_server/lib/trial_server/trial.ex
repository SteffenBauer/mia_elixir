defmodule TrialServer.Trial do

  @solution ~r/^([0-9a-fA-F]{32}):(-?[0-9]+)/

  def handle_packet({addr, port, "START"}) do
    {addr, port} |> new_trial()
  end

  def handle_packet({addr, port, data}) do
    case Regex.run(@solution, data) do
      [_, uuid, solution] ->
        handle_solution(addr, port, uuid, String.to_integer(solution))
      _ ->
        nil
    end
  end

  defp handle_solution(addr, port, uuid, solution) do
    trial = TrialServer.Store.pop_trial(uuid)
      |> update_values(solution)
    if trial.trials == 0 do
      {addr, port, generate_summary(trial)}
    else
      {t, uuid, solution} = generate_trial()
      TrialServer.Store.put_trial(%{trial | uuid: uuid, solution: solution})
      {addr, port, t}
    end
  end

  defp generate_summary(%{correct: correct, wrong: 0}) when correct > 0 do
    "ALL CORRECT"
  end
  defp generate_summary(%{correct: correct, wrong: wrong}) do
    "#{wrong} WRONG #{correct} CORRECT"
  end

  defp new_trial({addr, port}) do
    if TrialServer.Store.addr_in_store?(addr, port) do
      nil
    else
      {trial, uuid, solution} = generate_trial()
      trials = Application.get_env(:trial_server, :trials)
      TrialServer.Store.put_trial(%{addr: addr, port: port, uuid: uuid,
                                    solution: solution, trials: trials,
                                    correct: 0, wrong: 0})
      {addr, port, trial}
    end
  end

  defp generate_trial() do
    u = uuid()
    n = :rand.uniform(4) + 2
    nums = for _ <- 1..n, do: :rand.uniform(200) + 1
    {ty, solution} = case :rand.uniform(3) do
      1 -> {"ADD",      Enum.sum(nums)}
      2 -> {"SUBTRACT", hd(nums) - Enum.sum(tl(nums))}
      3 -> {"MULTIPLY", Enum.reduce(nums, &*/2)}
    end
    trial = ty <> ":" <> u <> ":" <> Enum.join(nums, ":")
    {trial, u, solution}
  end

  defp update_values(t, solution) do
    case t.solution do
      ^solution -> %{t | trials: t.trials - 1, correct: t.correct + 1}
      _         -> %{t | trials: t.trials - 1, wrong:   t.wrong + 1}
    end
  end

  defp uuid() do
    for _ <- 1..32 do :rand.uniform(16)-1 |> Integer.to_string(16) end
    |> Enum.join
  end

end
