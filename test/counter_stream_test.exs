defmodule CounterStreamTest do
  @moduledoc """
  A statemachine testing approach on top of `stream_data`. This approach
  is modeled after FishCake's `stream_code`.
  """

  use ExUnit.Case
  use ExUnitProperties

  #
  # 1. Bilde das stream_code Beispiel nach, insbesondere, was
  #    die map und bind Funktionen tun.
  # 2. Erzeuge command-Listen: prop = is_list
  # 3. Erzeuge command-Listen, die kein :fail enthalten dürfen -->
  #    muss fehlschlagen und die kleinste Liste finden

  property "create commands" do
    check all cmds <- unfold(initial_state(), &command/1, &next_state/2) do
      assert is_list(cmds)
    end
  end

  def initial_state(), do: :init

  # all commands are allowed, the failure is detected in next state
  def command(_state) do
    StreamData.frequency([
      {10, {:call, Counter, :clear, StreamData.constant([])}},
      {30, {:call, Counter, :inc, StreamData.constant([])}},
      {10, {:call, Counter, :get, StreamData.constant([])}},
      {1, {:call, Counter, :fail, StreamData.constant([])}}])
  end

  @type state_type :: any
  @type call_type :: {:call, atom, atom, list(any)}
  @spec next_state(call :: call_type, state :: state_type)
      :: {Macro.t, state_type}
  def next_state(c = {:call, _,:inc, _}, :init), do: {call(c), :zero}
  def next_state(c = {:call, _,:clear, _}, :init), do: {call(c), :zero}
  def next_state(c = {:call, _,:clear, _}, :zero), do: {call(c), :zero}
  def next_state(c = {:call, _,:inc, _}, :zero), do: {call(c), :one}
  def next_state(c = {:call, _,:inc, _}, :one), do: {call(c), :one}
  def next_state(c = {:call, _,:clear, _}, :one), do: {call(c), :zero}
  def next_state(c = {:call, _,:get, _}, state), do: {call(c), state}
  def next_state(c = {:call, _,:fail, _}, state), do: {call(c), state}

  defp call({:call, m, f, a}) do
    quote bind_quoted: [m: m, f: f, a: a] do
      apply(m, f, a)
    end
  end

  @spec unfold(acc, (acc -> StreamData.t(val)), (val, acc -> {other_val, acc})) ::
        StreamData.t(other_val) when acc: var, val: var, other_val: var
  def unfold(acc, value_fun, next_fun) do
    StreamData.sized(fn
      0 ->
        StreamData.constant(nil)
      size ->
        acc
        |> unfold(value_fun, next_fun, size)
        |> StreamData.map(&{:__block__, [], &1})
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
