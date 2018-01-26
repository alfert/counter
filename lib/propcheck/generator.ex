import TypeClass

defclass Counter.PropCheck.Generator do
  extend Witchcraft.Monad

  # access to monads and the like
  use Witchcraft
  # algebraic datastructures based data, sums and prods
  import Algae

  where do
    @opaque t(a) :: a
    @typedoc """
    A type for a generator function, which takes a seed and
    creates a new value.

    The value should by typed according to the type parameter `a`,
    however, parameterized types are not supported properly in `Algae`.
    Therefore we use the generic return type `any`.
    """
    @type gen_fun_t :: (non_neg_integer -> any)
    # @type gen_fun_t(a) :: (non_neg_integer, non_neg_integer -> a)
    defdata do
      gen_fun :: gen_fun_t() # \\\\ fn _, _ -> nil end
    end

    @doc """
    Generates a new value from a generator with a given
    size and seed.
    """
    @spec gen(t(a)) :: a when a: var
    def gen(gen)
  end

  properties do
    def generator_is_fun_1(gen) do
      a = generate(gen)
      is_function(a.gen_fun, 1)
    end
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

  # ### implement the super type classes
  # definst Witchcraft.Functor, for: Counter.PropCheck.Generator do
  #   @spec map(gen:: Counter.PropCheck.Generator.t(a), map_fun :: (a -> b)) ::
  #     Counter.PropCheck.Generator.t(b) when a: var, b: var
  #   def map(gen, map_fun) do
  #     fn seed, size ->
  #       gen.gen_fun.(seed, size)
  #       |> map_fun.()
  #     end
  #     |> Counter.PropCheck.Generator.new()
  #   end
  # end
