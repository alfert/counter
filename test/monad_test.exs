defmodule Counter.PropCheck.Monads.Test do

  use ExUnit.Case

  alias Counter.PropCheck.Generator
  alias Witchcraft.Functor
  describe "Generators are Monads" do

    test "create a default generator struct" do
      def_gen = Generator.new()
      # 5 is an arbitrary integer value
      assert nil == def_gen.run_gen.(5)
    end

    test "create a paraemterized generator struct" do
      seed = 5
      size = 10
      def_gen = Generator.new(fn my_seed -> my_seed*size end)
      assert is_function(def_gen.run_gen, 1)
      assert def_gen.run_gen.(seed) == seed*size
    end

    test "a generator functor provides a map" do
      gen = Generator.new(fn x -> 2*x end)
      mapper = fn x -> x + 1 end
      gen2 = gen |> Functor.map(mapper)
      for i <- 1..100 do
        assert gen2.run_gen.(i) == mapper.(2*i)
      end
    end

  end

end
