defmodule Counter.PropCheck.Property do

  alias Counter.PropCheck.Generator
  alias Counter.PropCheck.Result

  @type testable :: (... -> Result.t)

  ##
  ## TODO:
  ## - combining properties
  ##

  @typedoc """
  A property is a function from `Generator.seed_t` to `Result.t`
  """
  @type property_t :: (Generator.seed_t -> Result.t)

  @spec quickcheck(property_t, non_neg_integer) :: :Result.t
  def quickcheck(prop, nr_of_test_runs \\ 100) do
    seed = Generator.init_seed(:os.timestamp())
    quickcheck(prop, nr_of_test_runs, seed)
  end

  @spec quickcheck(property_t, pos_integer, Generator.seed_t) :: :Result.t
  def quickcheck(prop, nr_of_test_runs, seed) when nr_of_test_runs > 0  do
    qc_result = 1.. nr_of_test_runs
    |> Enum.flat_map_reduce({seed, Result.Success.new()}, fn _i, {s, _r}  ->
      {s1, s2} = Generator.split(s)
      case prop.(s1) do
        r = %Result.Failure{} -> {:halt, r}
        r -> {[], {s2, r}}
      end
    end)
    case qc_result do
      {[], {_s, r}} -> r
      {[], r } -> r
    end
  end


  @doc """
  Returns a property, i.e a function which takes a seed and returns
  a `Result.t`.
  """
  @spec for_all(Generator.t, testable) :: property_t
  def for_all(argGen, testable) do
    p = fn(seed) ->
      Generator.gen(argGen, seed)
      |> run_test(testable)
      |> Result.over_failure(fn r -> %Result.Failure{r | seed: seed} end)
    end
    p
  end

  @spec run_test(any, (any -> Result.t | boolean)) :: Result
  defp run_test(arg, test) do
    use Exceptional
    # use the Exceptional function `safe` to easily handle exceptions
    # such as assertions as if they would return a regular return value
    case safe(test).(arg) do
      true -> Result.Success.new()
      false -> Result.Failure.new(arg, nil)
      e = %ExUnit.AssertionError{} -> Result.Failure.new(arg, e)
    end
  end
end
