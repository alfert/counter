import TypeClass

defmodule Counter.PropCheck.Generator do

  # access to monads and the like
  use Witchcraft
  # algebraic datastructures based data, sums and prods
  import Algae

    @opaque t(a) :: a
    @typedoc """
    A type for a generator function, which takes a seed and
    creates a new value.

    The value should by typed according to the type parameter `a`,
    however, parameterized types are not supported properly in `Algae`.
    Therefore we use the generic return type `any`.
    """
    @type gen_fun_t :: (non_neg_integer -> any)
    # @type gen_fun_t(a) :: (non_neg_integer -> a)
    defdata do
      run_gen :: gen_fun_t()
    end


    @doc """
    Generates a new value from a generator with a given size.
    """
    @spec gen(t(a), integer) :: a when a: var
    def gen(%__MODULE__{run_gen: g}, seed), do: g.(seed)
    @doc """
    Curried version of gen/2. 
    """
    @spec gen(t(a)) :: (integer -> a) when a: var
    def gen(%__MODULE__{run_gen: g}), do: g

    def new(:gen_fun_t), do: new(fn _ -> nil end)
    def new(gen_fun) when is_function(gen_fun, 1) do
      %__MODULE__{run_gen: gen_fun}
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

    @spec convey(gen1 :: Generator.t(_a), gen2 :: Generator.t(_b)) :: Generator.t(_c)
      when _a: var, _b: var, _c: var
     def convey(gen1, %Generator{run_gen: run_gen2}) do
      Witchcraft.Functor.map(gen1, run_gen2)
    end
  end

  definst Witchcraft.Applicative, for: Counter.PropCheck.Generator do
    # Properties don't work good enough for functional values.
    @force_type_instance true
    alias Counter.PropCheck.Generator

    def of(%Generator{}, fun) when is_function(fun, 1) do
      Generator.new(fun)
    end
    def of(%Generator{}, data)  do
      Generator.new(fn _ -> data end)
    end
  end
