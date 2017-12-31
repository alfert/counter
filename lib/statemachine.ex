defmodule Statemachine do
  @moduledoc """
  Property-based testing or better data generation with a state machine in mind.
  The `fishcakez_unfold`-algorithm is borrowed from @fishcakez.
  """

  def commands(mod) do
    StreamData.unfold(mod.initial_state(), fn state ->
      # Assumption:
      # The bind peals the command, which is required to
      # identify the next state. The pealed command is given back
      # a constant - interesting, how do we shrink now?
      StreamData.bind(mod.command(state), fn cmd ->
        {StreamData.constant(cmd), mod.next_state(cmd, state)}
      end)
    end)
  end


  ##################################
  # @fishcake's unfold does not shrink properly.

  @spec fishcakez_unfold(acc, (acc -> StreamData.t(val)), (val, acc -> {other_val, acc})) ::
        StreamData.t(other_val) when acc: var, val: var, other_val: var
  def fishcakez_unfold(acc, value_fun, next_fun) do
    StreamData.sized(fn
      0 ->
        StreamData.constant(nil)
      size ->
        acc
        |> fishcakez_unfold(value_fun, next_fun, size)
        # |> StreamData.map(&{:__block__, [], &1})
    end)
  end

  defp fishcakez_unfold(acc, value_fun, next, size) do
    acc
    |> value_fun.()
    |> StreamData.bind(&fishcakez_unfold_next(&1, acc, value_fun, next, size))
  end

  defp fishcakez_unfold_next(value, acc, value_fun, next, size) do
    {quoted, acc} = next.(value, acc)
    acc
    |> fishcakez_unfold_tail(value_fun, next, size-1)
    |> StreamData.map(&[quoted | &1])
  end

  defp fishcakez_unfold_tail(acc, value_fun, next, size) do
    StreamData.frequency([
      {1, StreamData.constant([])},
      {size, fishcakez_unfold(acc, value_fun, next, size)}
    ])
  end

end
