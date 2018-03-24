defmodule Counter.PropCheck.Monads.Test do

  use ExUnit.Case

  alias Counter.PropCheck.Generator
  alias Counter.PropCheck.Arbitrary
  alias Counter.PropCheck.Property
  alias Counter.PropCheck.Result
  alias Witchcraft.Functor
  alias Witchcraft.Apply
  alias Witchcraft.Applicative
  use Witchcraft.Chain

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

    test "and provide a chain function" do
      seed = Generator.init_seed(0, 1, 2)
      i = Generator.integer(1..100)
      j = Generator.integer(1..100)
      {s1, s2} = Generator.split(seed)
      k = Generator.gen(i, s1) * Generator.gen(j, s2)
      # gen = Generator.new()

      chained = chain do
        let a = Generator.integer(1..100)
        let b = Generator.integer(1..100)
        lift(a, b, &( &1 * &2))
      end

      assert Generator.gen(chained, seed) == k
    end

  end

  describe "Generators provide Data as" do

    @nr_of_elements 32

    test "integer values" do
      for lower <- 1..10 do
        for upper <- lower+1..20 do
          sum = Generator.integer(lower .. upper)
          |> Stream.take(@nr_of_elements)
          |> Stream.map(fn v ->
            assert v <= upper
            assert v >= lower
            v
          end)
          |> Enum.sum()
          # This is to check, that the generated values are
          # really random.
          assert div(sum, @nr_of_elements) != 0

          # assert sum/@nr_of_elements <= (lower + upper + 2) / 2
          # assert sum/@nr_of_elements >= (lower + upper) / 2
        end
      end
    end

  end

  describe "Arbitrary shrinkers: " do

    test "0 is not shrinkable" do
      assert [] == Arbitrary.shrink(0)
    end

    test "bisect positive numbers from left to right" do
      children = Arbitrary.shrink(2048)
      list = Enum.to_list(children)
      assert [0,1024,1536,1792,1920,1984,2016,2032,2040,2044,2046,2047] == list
    end

    test "bisect negative numbers from left to right" do
      children = Arbitrary.shrink(-2048)
      list = Enum.to_list(children)
      assert [2048,0,-1024,-1536,-1792,-1920,-1984,-2016,-2032,-2040,-2044,-2046,-2047] == list
    end
  end

  describe "First properties: " do
    test "for all ints: they are greater then 1 (will fail)" do
      r = Generator.integer
      |> Property.for_all(fn n -> assert n > 1 end)
      |> Property.quickcheck()
      assert r == Result.Success.new()
    end
  end

end
