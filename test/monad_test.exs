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
      # This works because map does not care about the generator seed.
      gen = Generator.new(fn x -> 2*x end)
      mapper = fn x -> x + 1 end
      gen2 = gen |> Functor.map(mapper)
      for i <- 1..100 do
        assert gen2.run_gen.(i) == mapper.(2*i)
      end
    end

    test "a generator provides an apply" do
      # Apply.convey takes two generators and applies them as functions.
      seed = Generator.init_seed(0, 1, 2)
      const = fn v -> (fn _seed -> v end) end
      two = const.(2)
      inc = fn _seed -> (fn x -> x + 1 end) end
      gen_2 = Generator.new(two)
      gen_inc = Generator.new(inc)

      assert Generator.gen(Apply.ap(gen_inc, gen_2), seed) == 3
      for i <- 1..100 do
        g_conv = Generator.new(const.(i)) |> Apply.convey(gen_inc)
        assert Generator.gen(g_conv, seed) == (inc.(seed)).(const.(i).(seed))
      end
    end

    test "a generator is an applicative" do
      wrapped = Applicative.of(%Generator{}, &(&1+1))
      assert Generator.gen(wrapped, 5) == 6
    end

    test "a generator follows the identity law of applicative" do
      # Identitiy is a functional generator, i.e. it generates
      # a function which returns its argument (= identity)
      id = fn _seed -> (fn x -> x end) end
      # The value to double is the generator's parameter
      double = fn x -> (fn _seed -> x * 2 end) end

      seed = Generator.init_seed(0, 1, 2)
      for i <- 1..100 do
        gen = Generator.new(double.(i))
        app_id = id |> Generator.new() # |> Generator.gen()
        gen2 = Apply.ap(app_id, Generator.new(double.(i)))
          # |> Enum.map(&Generator.gen/1) # We now have a set generator functions
          # Apply.ap([Generator.new(id).gen], [Generator.new(double.(i))])
        x = Generator.gen(gen2, seed)
        assert x == Generator.gen(gen, seed)
      end
    end

    test "a generator provides an applicative lift" do
      one = fn _s -> 1 end # {1, s} end
      two = fn _s -> 2 end # {2, s} end
      pair = fn a, b -> {a, b} end
      gen_one = Generator.new(one)
      gen_two = Generator.new(two)
      gen_app = Apply.lift(gen_one, gen_two, pair)
      seed = Generator.init_seed(0, 1, 2)
      lifted = Generator.gen(gen_app, seed)
      l = fn seed ->
        {s1, s2} = Generator.split(seed)
        x = one.(s1)
        y = two.(s2)
        pair.(x, y)
      end

      assert l.(seed) == lifted
    end

  end

end
