defmodule CounterStreamTest do
  @moduledoc """
  A statemachine testing approach on top of `stream_data`.

  The test fails if the counter reaches `6`. The shrinking process
  works towards six times `inc()` and stops then.

  """

  use ExUnit.Case
  use ExUnitProperties
  alias Statemachine, as: SM
  require Logger
  import ExUnit.CaptureLog

  property "check the counter values command execution" do
    check all cmds <- SM.generate_commands(__MODULE__) do
      capture_log(fn -> Logger.debug "Commands are: #{inspect cmds}" end)
      Process.flag(:trap_exit, true)
      pid = case Counter.start_link() do
        {:ok, c_pid}  -> c_pid
        {:error, {:already_started, c_pid}} -> c_pid
      end
      events = SM.run_commands(__MODULE__, cmds)
      :ok = GenServer.stop(pid, :normal)
      wait_for_stop(pid)
      capture_log(fn -> Logger.error "Events = #{inspect events}" end)
      assert events.result == :ok
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
  def command(_) do
    StreamData.frequency([
      {10, {:call, Counter, :clear, StreamData.constant([])}},
      {30, {:call, Counter, :inc, StreamData.constant([])}},
      {10, {:call, Counter, :get, StreamData.constant([])}}
      ])
  end
  @type state_type :: any
  @type call_type :: {:call, atom, atom, list(any)}
  def next_state(state, _res, call), do: next_state(call, state)
  @spec next_state(call :: call_type, state :: state_type) :: state_type
  def next_state({:call, _,:inc, _}, :init), do: :zero
  def next_state({:call, _,:clear, _}, :init), do: :zero
  def next_state({:call, _,:clear, _}, :zero), do: :zero
  def next_state({:call, _,:inc, _}, :zero), do: :one
  def next_state({:call, _,:inc, _}, :one), do: :one
  def next_state({:call, _,:clear, _}, :one), do: :zero
  def next_state({:call, _,:get, _}, state), do: state

  # def precondition(:init, {:call, _, :get, _}), do: false
  def precondition(_, _), do: true

  @doc "The expected outcome. Only called after executing the command"
  def postcondition(:init, {:call, _,:inc, _}, _result), do: true
  def postcondition(:init, {:call, _,:clear, _}, _result), do: true
  def postcondition(:init, {:call, _,:get, _}, -1), do: true
  def postcondition(:zero, {:call, _,:clear, _}, _result), do: true
  def postcondition(:zero, {:call, _,:inc, _}, _result), do: true
  def postcondition(:inc, {:call, _,:inc, _}, _result), do: true
  def postcondition(:inc, {:call, _,:clear, _}, _result), do: true
  def postcondition(:zero, {:call, _,:get, _}, 0), do: true
  def postcondition(:one,  {:call, _,:get, _}, result), do: result > 0
  def postcondition(:one, {:call, _,:inc, _}, result), do: result != 6
  def postcondition(:one, {:call, _,:clear, _}, _result), do: true
  def postcondition(_old_state, {:call, _m, _f, _a}, _result) do
    false
  end

end
