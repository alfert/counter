defmodule Counter.PropCheck.Property do

  alias Counter.PropCheck.Generator
  alias Counter.PropCheck.Result

  @type testable :: (... -> Result.t)

  ##
  ## TODO:
  ## - Result Tree for shrinking - use Algae.Rose, because it is already
  ##   a functor (but eager - should we change that?)
  ## - combining properties
  ##

  @typedoc """
  A property is a function from `Generator.seed_t` to `Result.t`
  """
  @type property_t :: (Generator.seed_t -> Result.t)

  @spec quickcheck(property_t, non_neg_integer) :: Result.t
  def quickcheck(prop, nr_of_test_runs \\ 100) do
    seed = Generator.init_seed(:os.timestamp())
    quickcheck(prop, nr_of_test_runs, seed)
  end

  @spec quickcheck(property_t, pos_integer, Generator.seed_t) :: Result.t
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
      {s1, s2} = Generator.split(seed)
      Generator.gen(argGen, s1)
      |> run_test(testable, s2)
      |> Result.over_failure(fn r -> %Result.Failure{r | seed: seed} end)
    end
    p
  end

  @spec run_test(any, (any -> Result.t | boolean), Generator.seed_t) :: Result
  defp run_test(arg, test, seed) do
    use Exceptional
    # use the Exceptional function `safe` to easily handle exceptions
    # such as assertions as if they would return a regular return value
    case safe(test).(arg) do
      sub_prop when is_function(sub_prop, 1) ->
        sub_prop.(seed)
      value -> value
    end
    |> to_result(arg)
  end

  defp to_result(true, _), do: Result.Success.new()
  defp to_result(false, arg), do: Result.Failure.new(arg, nil)
  defp to_result(e = %ExUnit.AssertionError{}, arg) do
    stack = System.stacktrace()
    # |> Enum.drop_while(fn {mod, _, _, _} -> mod != __MODULE__ end)
    # |> Enum.drop_while(fn {mod, _, _, _} -> mod == __MODULE__ end)
    msg = Exception.format(:error, e, stack)
    Result.Failure.new(arg, e, msg, stack)
  end
  defp to_result(r = %Result.Failure{exception: msg}, arg), do:
    %Result.Failure{r | exception: "Argument: #{inspect arg}\n" <> msg}
  defp to_result(r = %Result.Success{}, _arg), do: r
end
