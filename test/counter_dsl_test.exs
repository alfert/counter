defmodule CounterModelTest.Dsl do
  @moduledoc """
  A statemachine testing approach on top of `stream_data`.

  This state machine has three simple states: `:init`, `:zero` and
  `:one`.

  It uses a new DSL for specifying the Statemachine.

  This state machine has an additional edge `fail()`, which is a non-
  existing function. Everytime it is called in the real run, the
  test is aborted with a failure. The shrinking process should run
  towards `clear()`-`inc()`-`fail()` or `inc()`-`inc()`-`fail()`.
  """

  use ExUnit.Case
  use ExUnitProperties
  alias Statemachine, as: SM
  require Logger
  import ExUnit.CaptureLog


  property "check the counter command execution" do
    check all cmds <- SM.generate_commands(__MODULE__) do
      IO.puts "Commands are: #{inspect cmds}"
      Process.flag(:trap_exit, true)
      pid = case Counter.start_link() do
        {:ok, c_pid}  -> c_pid
        {:error, {:already_started, c_pid}} -> c_pid
      end
      events = SM.run_commands(__MODULE__, cmds)
      :ok = GenServer.stop(pid, :normal)
      wait_for_stop(pid)
      assert events.result == :ok
    end
  end

  def no_failed_call?(c), do: not failed_call?(c)
  def failed_call?({_s, call}), do: failed_call?(call)
  def failed_call?({:call, _, c, _}), do: c == :fail

  def wait_for_stop(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end

  def initial_state(), do: :init

  defcommand(:inc) do
    args: constant([]),
    weight: 30,
    pre_condition: fn(_) -> true end,
    post_condition: fn
      :one, _args, result -> result > 1
      _state, _args, result > result > 0
    next_state: fn
      :zero, _args, _result -> :one
      :init, _, _ -> :zero
      :one, _, _ -> :one
  end

  defstate(:one) do
    command(Counter, :inc, constant([])) do
      weight: 30, # default: 1
      precondition: true, # default: true
      postcondition: case result do # default: true
        x -> x > 1
        _ -> false
      end
      next_state: case args do # default: stay in current state
        _ -> :one
      end
    end
  end

  ############
  # Use the modern eqc_statem way with grouping of commands and
  # its specifying functions. The counter has no args, so it is
  # somewhat boring. ==> Use the cache for that.
  # I am pretty sure that the above DSL can be mapped onto eqc
  # model of functions.


  # all commands are allowed, the failure is detected in next state
  def command(:one) do
    StreamData.frequency([
      {10, {:call, Counter, :clear, StreamData.constant([])}},
      {30, {:call, Counter, :inc, StreamData.constant([])}},
      {10, {:call, Counter, :get, StreamData.constant([])}},
      {1, {:call, Counter, :fail, StreamData.constant([])}}
    ])
  end
  def command(:init) do
    StreamData.frequency([
      {10, {:call, Counter, :clear, StreamData.constant([])}},
      {30, {:call, Counter, :inc, StreamData.constant([])}},
      # {10, {:call, Counter, :get, StreamData.constant([])}},
      # {1, {:call, Counter, :fail, StreamData.constant([])}}
      ])
  end
  def command(_) do
    StreamData.frequency([
      {10, {:call, Counter, :clear, StreamData.constant([])}},
      {30, {:call, Counter, :inc, StreamData.constant([])}},
      {10, {:call, Counter, :get, StreamData.constant([])}},
      # {1, {:call, Counter, :fail, StreamData.constant([])}}
      ])
  end
  @type state_type :: any
  @type call_type :: {:call, atom, atom, list(any)}
  def next_state(state, _res, call), do: next_state(call, state)
  @spec next_state(call :: call_type, state :: state_type)
      :: {Macro.t, state_type}
  def next_state({:call, _,:inc, _}, :init), do:  :zero
  def next_state({:call, _,:clear, _}, :init), do:  :zero
  def next_state({:call, _,:clear, _}, :zero), do:  :zero
  def next_state({:call, _,:inc, _}, :zero), do:  :one
  def next_state({:call, _,:inc, _}, :one), do:  :one
  def next_state({:call, _,:clear, _}, :one), do:  :zero
  def next_state({:call, _,:get, _}, state), do:  state
  # allow fail only in state :one
  def next_state({:call, _,:fail, _}, state = :one), do: state

  def precondition(:init, {:call, _, :get, _}), do: false
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
  def postcondition(:one, {:call, _,:inc, _}, result), do: result > 1
  def postcondition(:one, {:call, _,:clear, _}, _result), do: true
  def postcondition(_old_state, {:call, _m, _f, _a}, _result) do
    false
  end

end
