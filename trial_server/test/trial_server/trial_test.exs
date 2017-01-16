defmodule TrialServer.TrialTest do
  use ExUnit.Case
  alias TrialServer.Trial

  def uuid() do
    for n <- 0..15 do
      :rand.uniform(256)
      |> Integer.to_string(16)
    end |> Enum.join
  end

end
