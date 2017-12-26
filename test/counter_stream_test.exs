defmodule CounterStreamTest do
  @moduledoc """
  A statemachine testing approach on top of `stream_data`. This approach
  is modeled after FishCake's `stream_code`.
  """

  use ExUnit.Case
  use ExUnitProperties

  #
  # 1. Generation of call tuples or the likes works
  # 2. The shrinking of the generated list does not work.

  # property "find the fail command" do
  #   check all cmds <- list_of(command(:what_ever)) do
  #     assert Enum.all?(cmds, fn {:call, _, c, _} -> c != :fail end)
  #   end
  # end
  #
  # property "find the mapped fail command" do
  #   check all cmds <- (command(:what_ever)
  #       |> StreamData.map(fn {:call, _, c, _} -> {c} end)  |> list_of()) do
  #     assert Enum.all?(cmds, & ( &1!= {:fail}))
  #   end
  # end
  #
  # property "find the bound fail command" do
  #   check all cmds <- gen_list(fn -> command(:what_ever)end) do
  #     assert Enum.all?(cmds, & ( &1!= :fail))
  #   end
  # end

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

  property "create commands" do
    check all cmds <- unfold(initial_state(), &command/1, &next_state/2) do
      IO.puts "cmds = #{inspect cmds}"
      assert Enum.all?(cmds, & ( &1!= :fail))
      # assert Enum.all?(cmds, fn {:call, _, c, _} -> c != :fail end)
      # Process.flag(:trap_exit, true)
      # pid = case Counter.start_link() do
      #   {:ok, c_pid}  -> c_pid
      #   {:error, {:already_started, _c_pid}} -> :kapputt # c_pid
      # end
      # Code.eval_quoted(cmds, [], __ENV__)
      # :ok = GenServer.stop(pid, :normal)
      # wait_for_stop(pid)
    end
  end

  def wait_for_stop(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
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

  defp call_id({:call, _m, _f, _a} = c), do: c
  defp call({:call, _m, f, _a} ), do: f

  defp call_x({:call, m, f, a}) do
    quote location: :keep, bind_quoted: [m: m, f: f, a: a] do
      assert f != :fail
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
