import TypeClass

defmodule Counter.PropCheck.Generator do

  # access to monads and the like
  # use Witchcraft.Functor
  # use Witchcraft.Apply
  # use Witchcraft.Applicative
  # use Witchcraft.Chain
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

    ###
    # Generator function for integer values within a range.
    ###
    @spec choose(integer, integer) :: gen_fun_t(integer)
    defp choose(low, high) when is_integer(low) and is_integer(high) and Kernel.<(low,high) do
      n = high - low
      fn seed ->
        {rand_value, _new_seed} = :rand.uniform_s(n, seed)
        low + rand_value
      end
    end

    @doc """
    Trivial generator, which generates always the same constant
    """
    @spec constant(v :: a) :: t(a) when a: var
    def constant(v), do: new(fn _ -> v end)

    @doc """
    Generator for integer values within a certain range.
    """
    def integer(lower..upper) do
      choose(lower, upper) |> new()
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
      :rand.seed_s(:exs1024, {s1, s2, s3})
    end
    @spec init_seed({integer, integer, integer}) :: seed_t
    def init_seed({s1, s2, s3}), do: init_seed(s1, s2, s3)

    def my_lift(gen1, gen2, fun) do
      fn seed ->
        {s1, s2} = split(seed)
        {v1, _s} = gen(gen1, s1)
        {v2, _s} = gen(gen2, s2)
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

    # This is the implementation of Enumerable.reduce/3. It's here because it
    # needs split_seed/1 and call/3 which are private.
    @doc false
    @spec __reduce__(t, Enumerable.acc, Enumerable.reducer) :: Enumerable.result
    def __reduce__(generator, acc, fun) do
      reduce(generator, acc, fun, init_seed(:os.timestamp()), _initial_size = 1, _max_size = 100)
    end

    defp reduce(_generator, {:halt, acc}, _fun, _seed, _size, _max_size) do
      {:halted, acc}
    end

    defp reduce(generator, {:suspend, acc}, fun, seed, size, max_size) do
      {:suspended, acc, &reduce(generator, &1, fun, seed, size, max_size)}
    end

    defp reduce(generator, {:cont, acc}, fun, seed, size, max_size) do
      {seed1, _seed2} = split(seed)
      next = gen(generator, seed)
      reduce(generator, fun.(next, acc), fun, seed1, min(max_size, size + 1), max_size)
    end

end
  ############ A Generator is also a stream
  defimpl Enumerable, for: Counter.PropCheck.Generator do
    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}

    def reduce(gen, acc, fun), do: @for.__reduce__(gen, acc, fun)
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

  definst Witchcraft.Chain, for: Counter.PropCheck.Generator do
    # Properties don't work good enough for functional values.
    @force_type_instance true
    alias Counter.PropCheck.Generator

    def chain(gen, link_fun) do
      # chain = gen |> map(link_fun) |> flatten()
      fn seed ->
        {s1, s2} = Generator.split(seed)
        gen
        |> Generator.gen(s1)
        |> link_fun.()
        |> Generator.gen(s2)
      end
    end

  end
