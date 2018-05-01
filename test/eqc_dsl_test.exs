defmodule Counter.Propcheck.TestDSL do

  use ExUnit.Case
  use PropCheck
  use Counter.PropCheck.StateM


  command :negate do
    def impl(x), do: -x
    def pre(true, _c), do: false
    def pre(false, _c), do: true
  end

  def this_function_exist(arg), do: arg


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
  end

  test "default functios are available" do
    assert negate_next(37, :foo, :bar) == 37
    assert negate_post(37, :foo, :bar) == true
  end

end
