import TypeClass

defmodule Counter.PropCheck.Generator do

  # access to monads and the like
  use Witchcraft.Functor
  use Witchcraft.Apply
  use Witchcraft.Applicative
  use Witchcraft.Monad
  # algebraic datastructures based data, sums and prods
  import Algae

    @opaque t(a) :: a

    @opaque seed_t :: :rand.state()

    @typedoc """
    A type for a generator function, which takes a seed and
    creates a new value.

    The value should by typed according to the type parameter `a`,
    however, parameterized types are not supported properly in `Algae`.
    Therefore we use the generic return type `any`.
    """
    @type gen_fun_t :: (seed_t -> any)
    @type gen_fun_t(a) :: (seed_t -> a)
    @type internal_gen_fun_t(a) :: (seed_t -> {a, seed_t})
    defdata do
      run_gen :: gen_fun_t()
    end


    @doc """
    Curried version of gen/2.
    """
    @spec gen(t(a)) :: gen_fun_t(a) when a: var
    def gen(%__MODULE__{run_gen: g}), do: g

    @doc """
    Generates a new value from a generator with a given size.
    """
    @spec gen(t(a), seed_t) :: a when a: var
    def gen(%__MODULE__{run_gen: g}, seed), do: g.(seed)
    def gen(g, seed) when is_function(g, 1), do: g.(seed)

    def new(:gen_fun_t), do: new(fn _ -> nil end)
    def new(gen_fun) when is_function(gen_fun, 1) do
      %__MODULE__{run_gen: gen_fun}
    end

    @spec choose(integer, integer) :: internal_gen_fun_t(integer)
    def choose(low, high) when is_integer(low) and is_integer(high) and Kernel.<(low,high) do
      n = high - low
      fn seed ->
        {rand_value, new_seed} = :rand.uniform_s(seed, n)
        {low + rand_value, new_seed}
      end
    end

    @doc """
    Splits a seed into two separated seeds.

    It uses the `jump` function of the Erlang `:rand` function.
    """
    @spec split(seed_t) :: {seed_t, seed_t}
    def split(seed) do
      split1 = :rand.jump(seed)
      split2 = :rand.jump(split1)
      {split1, split2}
    end

    @doc """
    Initializes the random number generator `:exs1024` with the three
    given integer parameters. Useful in particular for testing.
    """
    @spec init_seed(integer, integer, integer) :: seed_t
    def init_seed(s1, s2, s3) do
      :rand.seed(:exs1024, {s1, s2, s3})
    end

    def my_lift(gen1, gen2, fun) do
      fn seed ->
        {s1, s2} = split(seed)
        {v1, _s} = Generator.gen(gen1, s1)
        {v2, _s} = Generator.gen(gen2, s2)
        fun.(v1, v2)
      end
      |> new()
    end

    def my_lift2(gen1, gen2, fun) do
      # curried_gen.gen(seed) returns a function waiting for a second value
      # since Functor.lift curries fun.
      curried_gen = gen1 |> lift(fun)

      curried_gen
      |> fn f -> convey(gen2, f) end.()
    end

end
  ############ Generator for TypeClass
  defimpl TypeClass.Property.Generator, for: Counter.PropCheck.Generator do
    def generate(_) do
      [
        fn _ -> 5 end,
        fn _ -> :a end,
        fn _ -> [1, 2, 3] end
      ]
      |> Enum.random()
      |> Counter.PropCheck.Generator.new()
    end
  end

  ### implement the super type classes
  definst Witchcraft.Functor, for: Counter.PropCheck.Generator do
    # Properties don't work good enough for functional values.
    @force_type_instance true

    @spec map(gen:: Counter.PropCheck.Generator.t(a), map_fun :: (a -> b)) ::
      Counter.PropCheck.Generator.t(b) when a: var, b: var
    def map(gen, map_fun) do
      fn seed ->
        gen.run_gen.(seed)
        |> map_fun.()
      end
      |> Counter.PropCheck.Generator.new()
    end
  end

  definst Witchcraft.Apply, for: Counter.PropCheck.Generator do
    # Properties don't work good enough for functional values.
    @force_type_instance true
    alias Counter.PropCheck.Generator

    @spec convey(gen1 :: Generator.t(_a), gen2_fun :: Generator.t((_b -> _c)) ):: Generator.t(_c)
      when _a: var, _b: var, _c: var
    def convey(gen1, gen2_fun) do
      # gen2_fun is a Generator, which generates a function with one
      # argument which needs to be applied to get a "real" value.
      # This is what convey produces.
      fn seed ->
        {s1, s2} = Generator.split(seed)
        v1 = Generator.gen(gen1, s1)
        Generator.gen(gen2_fun, s2).(v1)
      end
      |> Generator.new()
    end
  end

  definst Witchcraft.Applicative, for: Counter.PropCheck.Generator do
    # Properties don't work good enough for functional values.
    @force_type_instance true
    alias Counter.PropCheck.Generator

    def of(%Generator{}, fun) when is_function(fun, 1) do
      Generator.new(fun)
    end
    def of(%Generator{}, gen = %Generator{}), do: gen
    def of(%Generator{}, data)  do
      Generator.new(fn _ -> data end)
    end
  end
