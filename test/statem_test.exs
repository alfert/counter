defmodule Counter.StateM.Test do
  @moduledoc """
  Tests the functions from `StateM`. The reference modul is `cache_eqc_test.exs`,
  i.e. `CounterTest.Cache.Eqc`
  """

  use ExUnit.Case
  alias Counter.StateM

  @mod_under_test CounterTest.Cache.Eqc
  @mod_under_test_file "cache_eqc_test.exs"

  test "am I the module loaded and discoverable?" do
    [{mod, _bin_code}] = Code.load_file(__ENV__.file)
    assert mod == __MODULE__
  end

  test "find the 3 commands" do
    [{mod, bin_code}] = Code.load_file(@mod_under_test_file, "./test")
    assert mod == @mod_under_test
    {:module, @mod_under_test} = Code.ensure_compiled(@mod_under_test)

    cmds = StateM.find_commands(bin_code)
    assert cmds == [{"cache", 2}, {"find", 1}, {"flush", 0}]

  end

  test "find some specific functions" do
    [{mod, bin_code}] = Code.load_file(@mod_under_test_file, "./test")
    assert mod == @mod_under_test
    {:module, @mod_under_test} = Code.ensure_compiled(@mod_under_test)
    {@mod_under_test, funs} = StateM.all_functions(bin_code)

    assert StateM.find_fun(funs, "initial_state", [0])
    assert StateM.find_fun(funs, "weight", [2])
    assert StateM.find_fun(funs, "flush_post", [3])
    assert not StateM.find_fun(funs, "command_lazy_tree", [2])
    assert not StateM.find_fun(funs, "initial_state", [1])
    assert StateM.find_fun(funs, "initial_state", [0, 1])
    assert StateM.find_fun(funs, "_state", [0])
  end

  test "the command list has the proper functions" do
    [{mod, bin_code}] = Code.load_file(@mod_under_test_file, "./test")

    cmd_list = StateM.command_list(bin_code)

    assert length(cmd_list) == 3
    assert {:cmd, ^mod, "cache", _g} = hd(cmd_list)
  end

end
