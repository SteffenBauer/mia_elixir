defmodule TrialStoreTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    {:ok, store} = Agent.start(&TrialServer.Store.init/0)
    on_exit fn -> Agent.stop(store) end
    :ok
  end

  @entry1 %{addr: {127,0,0,1}, port: 50000,
            uuid: "AAAABBBBCCCCDDDDEEEEFFFF00001111",
            solution: 123, trials: 5, correct: 0, wrong: 0}
  @entry2 %{addr: {127,0,0,2}, port: 40000,
            uuid: "AAAABBBBCCCCDDDDEEEEFFFF00002222",
            solution: 321, trials: 5, correct: 0, wrong: 0}

  test "No entry in store" do
    refute TrialServer.Store.addr_in_store?(@entry1.addr, @entry1.port)
    refute TrialServer.Store.addr_in_store?(@entry2.addr, @entry2.port)
  end

  test "Put entry in store" do
    assert TrialServer.Store.put_trial(@entry1)
    assert TrialServer.Store.addr_in_store?(@entry1.addr, @entry1.port)
  end

  test "Wrong entry in store" do
    assert TrialServer.Store.put_trial(@entry1)
    refute TrialServer.Store.addr_in_store?(@entry2.addr, @entry1.port)
    refute TrialServer.Store.addr_in_store?(@entry2.addr, @entry2.port)
  end

  test "Retrieve entry from store" do
    assert TrialServer.Store.put_trial(@entry1)
    assert @entry1 == TrialServer.Store.pop_trial(@entry1.uuid)
    assert nil == TrialServer.Store.pop_trial(@entry1.uuid)
  end

  test "Two entries" do
    assert TrialServer.Store.put_trial(@entry1)
    assert TrialServer.Store.put_trial(@entry2)
    TrialServer.Store.pop_trial(@entry1.uuid)
    refute TrialServer.Store.addr_in_store?(@entry1.addr, @entry1.port)
    assert TrialServer.Store.addr_in_store?(@entry2.addr, @entry2.port)
    assert @entry2 == TrialServer.Store.pop_trial(@entry2.uuid)
  end

end
