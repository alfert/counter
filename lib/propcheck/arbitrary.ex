import TypeClass
defclass Counter.PropCheck.Arbitrary do
  where do
    @doc """
    Generates arbitrary values from the given generator
    """
    @spec arbitrary(Counter.PropCheck.Generator.t(a)):: a when a: var
    def arbitrary(generator)

    @doc """
    Shrinks a value and produces a (lazy?) list of shrunk values.
    """
    @spec shrink(a) :: [a] when a: var
    def shrink(value)
  end
  properties do
    def arbitrary_has_no_properties(_value) do
      true
    end
  end

end
