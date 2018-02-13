defmodule Counter.PropCheck.Monads.Test do

  use ExUnit.Case

  alias Counter.PropCheck.Generator
  alias Witchcraft.Functor
  alias Witchcraft.Apply
  alias Witchcraft.Applicative

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

    test "a generator provides an apply" do
      # Apply.convey takes two generators and applies them as functions.
      f1 = fn x -> 2 * x end
      f2 = fn x -> x + 1 end
      gen1 = Generator.new(f1)
      gen2 = Generator.new(f2)
      for i <- 1..100 do
        assert Apply.convey(gen2, gen1).run_gen.(i) == f1.(f2.(i))
        gens = [gen2, gen1] |> Enum.map(&Generator.gen/1)
        assert Apply.ap(gens, [i]) == [f2.(i), f1.(i)]
      end
    end

    test "a generator is an applicative" do
      wrapped = Applicative.of(%Generator{}, &(&1+1))
      assert Generator.gen(wrapped, 5) == 6
    end

    test "a generator follows the identity law of applicative" do
      id = fn x -> x end
      double = fn x -> 2 * x end
      gen = Generator.new(double)
      for i <- 1..100 do
        gen2 = [gen]
          |> Enum.map(&Generator.gen/1)
          |> Apply.ap([Applicative.of(Generator.new(), id)])
        x = Generator.gen(gen2, i)
        assert x == Generator.gen(gen, i)
      end
    end

    test "a generator provides an applicative lift" do
      one = fn s -> {1, s} end
      two = fn s -> {2, s} end
      pair = fn a, b -> {a, b} end
      gen_one = Generator.new(one)
      gen_two = Generator.new(two)
      gen_app = Apply.lift(gen_one, gen_two, pair)
      seed = Generator.init_seed(0, 1, 2)
      lifted = gen_app.run_gen.(seed)
      l = fn seed ->
        {s1, s2} = Generator.split(seed)
        {x, _s3} = one.(s1)
        {y, _s4} = two.(s2)
        pair.(x, y)
      end

      assert l.(seed) == lifted
    end

  end

end
