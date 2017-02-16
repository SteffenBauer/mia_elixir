defmodule TrialServer.UUID do

  def uuid() do
    for _ <- 0..15 do
      :rand.uniform(256)
      |> Integer.to_string(16)
      |> String.pad_leading(2, "0")
    end |> Enum.join
  end

end
