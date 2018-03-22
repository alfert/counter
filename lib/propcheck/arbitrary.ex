import TypeClass
defclass Counter.PropCheck.Arbitrary do
  where do
    @doc """
    Generates arbitrary values from the given generator as a stream 
    of values.
    """
    @spec arbitrary(Counter.PropCheck.Generator.t(a)):: Enumerable.t(a) when a: var
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

  def run_gen(generator), do:
    generator |> Counter.PropCheck.Generator.gen()

end

# alias the fresh defined type class for shorter source code.
alias Counter.PropCheck.Arbitrary

# Implementation for all types that do not support shrinking
definst Arbitrary, for: Any do
  def shrink(_), do: []
  def arbitrary(generator), do: Arbitrary.run_gen(generator)
end

definst Arbitrary, for: Integer do
  def arbitrary(generator), do: Arbitrary.run_gen(generator)
  @doc """
  Shrinks an integer. There are three approaches:
  * if `n` is `0`, then there is nothing to do.
  * if `n` is negative, try the absolute value of `n`
  * otherwise do an interval bisection from 0 towards n.
  """
  def shrink(0), do: []
  def shrink(n) when n < 0, do: Stream.concat([-n], bisect(n))
  def shrink(n), do: bisect(n)

  defp bisect(n) do
    n
    |> Stream.iterate(fn m -> div(m, 2) end)
    |> Stream.map(fn m -> n - m end)
    |> Stream.take_while(fn m -> abs(m) < abs(n) end)
  end
end
