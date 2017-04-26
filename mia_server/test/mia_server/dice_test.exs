defmodule MiaServer.DiceTest do
  use ExUnit.Case
  alias MiaServer.Dice

  test "Equal dice sets should be equal" do
    first = Dice.new 3,1
    second = Dice.new 1,3
    assert Dice.equal? first, second
  end

  test "Different dice sets should not be equal" do
    first = Dice.new 3,1
    second = Dice.new 2,3
    refute Dice.equal? first, second
  end

  test "Comparison is not reflexive" do
    first = Dice.new 3,1
    refute Dice.higher? first, first
  end

  test "Comparison should order simple rolls correctly" do
    thirtyone = Dice.new 3,1
    fortyone = Dice.new 4,1
    fortytwo = Dice.new 4,2
    assert Dice.higher? fortyone, thirtyone
    assert Dice.higher? fortytwo, fortyone
    assert Dice.higher? fortytwo, thirtyone
  end

  test "Comparison should order doubles correctly" do
    sixtyfive = Dice.new 6,5
    doubleone = Dice.new 1,1
    doublesix = Dice.new 6,6
    assert Dice.higher? doubleone, sixtyfive
    assert Dice.higher? doublesix, doubleone
    assert Dice.higher? doublesix, sixtyfive
  end

  test "Comparison should order MIA correctly" do
    mia = Dice.new 2,1
    doublesix = Dice.new 6,6
    thirtyone = Dice.new 3,1
    assert Dice.higher? mia, doublesix
    refute Dice.higher? thirtyone, mia
  end

  test "2,1 is a mia" do
    mia = Dice.new 2,1
    assert Dice.mia? mia
  end

  test "Should not declare double two as mia" do
    doubletwo = Dice.new 2,2
    refute Dice.mia? doubletwo
  end

  test "Order of dice is not relevant" do
    reversesixtyone = Dice.new 1,6
    thirtyone = Dice.new 3,1
    assert Dice.higher? reversesixtyone, thirtyone
  end

  test "Dice should be nicely formatted" do
    thirtyone = Dice.new 3,1
    assert "#{thirtyone}" == "3,1"
  end

  test "Dice should parse to their own representation" do
    thirtyone = Dice.new 3,1
    parsed = thirtyone |> to_string |> Dice.parse
    assert Dice.equal? thirtyone, parsed
  end

  test "Garbage must not be parsed" do
    assert Dice.parse("Garbage") == nil
  end

  test "Invalid dice" do
    assert Dice.new(0, 4) == :invalid
    assert Dice.new(7, 2) == :invalid
    assert Dice.new(4, 9) == :invalid
    assert Dice.new("a", "z") == :invalid
  end

end
