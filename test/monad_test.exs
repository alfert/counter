defmodule Counter.PropCheck.Monads.Test do

  use ExUnit.Case

  alias Counter.PropCheck.Generator
  describe "Generators are Monads" do

    test "create a default generator struct which is not a function" do
      def_gen = Generator.new()
      assert :gen_fun_t == def_gen.gen_fun
    end

    test "create a paraemterized generator struct" do
      seed = 5
      size = 10
      def_gen = Generator.new(fn my_seed, my_size -> my_seed*my_size end)
      assert is_function(def_gen.gen_fun, 2)
      assert def_gen.gen_fun.(seed, size) == seed*size
    end

  end

end
