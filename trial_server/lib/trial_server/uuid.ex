defmodule TrialServer.UUID do

  def uuid() do
    for _ <- 1..32 do
      :rand.uniform(16)-1
      |> Integer.to_string(16)
    end |> Enum.join
  end
end
