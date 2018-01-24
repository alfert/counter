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
    A type for a generator function, which takes a seed and size and
    creates a new value.

    The value should by typed according to the type parameter `a`,
    however, parameterized types are not supported properly in `Algae`.
    Therefore we use the generic return type `any`.
    """
    @type gen_fun_t :: (non_neg_integer, non_neg_integer -> any)
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
    def generator_is_fun_2(gen) do
      a = generate(gen)
      is_function(a.gen_fun, 2)
    end
  end

end
