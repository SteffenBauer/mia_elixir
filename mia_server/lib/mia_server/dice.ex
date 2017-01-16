defmodule MiaServer.Dice do
  defstruct die1: nil, die2: nil

  def new(die1, die2), do: %MiaServer.Dice{die1: max(die1, die2), die2: min(die1, die2) }

  def equal?(dice1, dice2), do: dice1 == dice2

  def higher? %MiaServer.Dice{die1: a1, die2: a2}, %MiaServer.Dice{die1: b1, die2: b2} do
    case {a1,a2,b1,b2} do
      {a,b,a,b} -> false  # Comparison is not reflexive
      {2,1,_,_} -> true   # Mia is higher than anything
      {_,_,2,1} -> false  # Nothing is higher than Mia
      {a,a,b,b} -> a > b  # Double versus double
      {a,a,_,_} -> true   # A double is higher than any simple
      {_,_,b,b} -> false  # Simples are lower than any double
      {x,a,x,b} -> a > b  # Simples with equal first dice
      {a,_,b,_} -> a > b  # Simples with different first dice
    end
  end

  def mia?(%MiaServer.Dice{die1: 2, die2: 1}), do: true
  def mia?(%MiaServer.Dice{die1: _, die2: _}), do: false

  defimpl String.Chars do
    def to_string(%MiaServer.Dice{die1: a, die2: b}), do: "#{a},#{b}"
  end

  def parse str do
    case (Regex.run ~r/^([1-6]),([1-6])$/, str) do
      [_, a, b] -> new String.to_integer(a), String.to_integer(b)
      nil     -> nil
    end
  end

end

defmodule MiaServer.DiceRoller do
  def seed, do: :rand.seed(:erlang.timestamp)
  def roll, do: MiaServer.Dice.new(:rand.uniform(6), :rand.uniform(6))
end

