defmodule Statemachine do
  @moduledoc """
  Property-based testing or better data generation with a state machine in mind.
  The `unfold`-algorithm is borrowed from @fishcake.
  """


  #######################
  # `gen_list` does not work, since it builds a direct list.

  def gen_list(gen) do
    StreamData.sized(fn
        0 -> nil
        n -> gen_list(n, gen)
      end)
  end
  def gen_list(0, _), do: StreamData.constant([])
  def gen_list(n, gen) do
    gen.()
    |> StreamData.bind(fn value -> [value | gen_list(n-1, gen)] end)
    |> StreamData.map(fn {:call, _, c, _} -> c end)
  end

  ##################################
  # unfold does not shrink properly.

  @spec unfold(acc, (acc -> StreamData.t(val)), (val, acc -> {other_val, acc})) ::
        StreamData.t(other_val) when acc: var, val: var, other_val: var
  def unfold(acc, value_fun, next_fun) do
    StreamData.sized(fn
      0 ->
        StreamData.constant(nil)
      size ->
        acc
        |> unfold(value_fun, next_fun, size)
        # |> StreamData.map(&{:__block__, [], &1})
    end)
  end

  defp unfold(acc, value_fun, next, size) do
    acc
    |> value_fun.()
    |> StreamData.bind(&unfold_next(&1, acc, value_fun, next, size))
  end

  defp unfold_next(value, acc, value_fun, next, size) do
    {quoted, acc} = next.(value, acc)
    acc
    |> unfold_tail(value_fun, next, size-1)
    |> StreamData.map(&[quoted | &1])
  end

  defp unfold_tail(acc, value_fun, next, size) do
    StreamData.frequency([
      {1, StreamData.constant([])},
      {size, unfold(acc, value_fun, next, size)}
    ])
  end

end
