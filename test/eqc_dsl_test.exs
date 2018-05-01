defmodule Counter.Propcheck.TestDSL do

  use ExUnit.Case
  use PropCheck
  use Counter.PropCheck.StateM


  command :negate do
    def impl(x), do: -x
    def pre(true, _c), do: false
    def pre(false, _c), do: true
    def args(_s), do: fixed_list([pos_integer()])
  end

  command :nonsense do
    def impl(), do: :tralala
    def pre(_, _), do: false
  end

  def this_function_exist(arg), do: arg
  def initial_state(), do: false

  test "generated functions exist" do
    assert function_exported?(__MODULE__, :this_function_exist, 1)

    assert function_exported?(__MODULE__, :negate_pre, 2)

    refute function_exported?(__MODULE__, :impl, 1)
    assert function_exported?(__MODULE__, :negate, 1)
  end

  test "generated functions have correct bodies" do
    assert negate_pre(true, 5) == false
    assert negate_pre(false, 4) == true
    assert negate(5) == -5
    assert negate(-6) == 6
    assert negate_args(85) == fixed_list([pos_integer()])
  end

  test "default functios are available" do
    assert negate_next(37, :foo, :bar) == 37
    assert negate_post(37, :foo, :bar) == true
    assert nonsense_args(85) == fixed_list([])
  end

  test "generate the negations arguments" do
    {:ok, cmds} = produce(commands(__MODULE__), 1)
    init = initial_state()
    assert {^init, {:set, {:var, 1}, {:call, __MODULE__, :negate, [_]}}} = hd(cmds)
  end

  test "list of commands definition" do
    assert Enum.sort(@commands) == ["negate", "nonsense"]
  end

  test "command_list finds all commands" do
    assert Enum.sort(find_commands(__MODULE__)) == [{"negate", 0}, {"nonsense", 0}]
    neg = command_list(__MODULE__, "") |> Enum.sort() |> hd()
    assert {:cmd, __MODULE__, "negate", _arg_fun} = neg
  end

end
