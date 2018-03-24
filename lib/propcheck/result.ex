import TypeClass
defmodule Counter.PropCheck.Result do
  alias Counter.PropCheck.Generator
  import Algae
  @moduledoc """
  This is the result of a property check. Either it is a sucess
  or it is a failure with a counter example and the seed to recreate
  the failure.

  A `Result` is also a `Witchcraft.Monoid`, ie. we can append
  several results together via `<>/2`. In this case the left most
  failure is reported, all other failures are ignored.
  """
  alias Result.{Failure, Success}
  defsum do
    defdata Success :: none() # no info in case of success
    defdata Failure do
      counter_example :: String.t
      seed :: {integer, integer, integer}
      exception :: String.t | ExUnit.AssertionError.t
      stacktrace :: any
    end
  end

  @doc """
  Creates a new `Failure` struct with the given counter example `ct_ex`
  and the `seed`.
  """
  @spec new(ct_ex :: String.t, seed :: Generator.seed_t) :: Failure.t
  defdelegate new(ct_ex, seed, msg \\ "", stack \\ System.stacktrace()), to: Failure, as: :new

  @spec over_failure(t, (t -> t)) :: t
  def over_failure(r = %Success{}, _fun), do: r
  def over_failure(r, fun), do: fun.(r)

  properties do
    def over_failure_with_id(data) do
      a = TypeClass.Property.Generator.generate(data)
      IO.puts("over_failure_with_id: a = #{inspect a}")
      Counter.PropCheck.Result.over_failure(a, fn x -> x end) == a
    end
  end
end

## Make the new module easily available
alias Counter.PropCheck.Result

# we need to generate value for property testing of type class laws
defimpl TypeClass.Property.Generator, for: Result do
  def generate(_) do
    Stream.unfold(:rand.uniform(2), fn n ->
      r = case n do
        1 -> Result.new()
        2 -> Result.new(generate(""), generate({1, 2, 3}))
      end
      {r, :rand.uniform(2)}
    end)
  end
end

definst Witchcraft.Semigroup, for: Result do
  @doc """
  Appending to failure does not change anything, the leftmost failure
  is preserved. In the case of a left success, we are only interested in
  the right result.
  """
  def append(l = %Result.Failure{}, _r), do: l
  def append(_, r), do: r
end

definst Witchcraft.Monoid, for: Result do
  @doc """
  An empty `Result` is a sucess.
  """
  def empty(_r), do: Result.new()
end
