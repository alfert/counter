defmodule CounterTest do
  @moduledoc """
  A simple state machine for property testing the `Counter`.

  We use only three states: `:init`, `:zero` and `:one`.
  """

  use ExUnit.Case
  use PropCheck.StateM
  alias PropCheck.StateM

  @behaviour :proper_statem
  require Logger

  @typedoc """
  The type for the state of the state machine model.
  """
  @type state_t :: :init | :zero | :one

  @type call_t :: {:call, mfa}

  def wait_for_stop(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end

  property "run a failing command sequence" do
    forall cmds <- commands(__MODULE__) do
      IO.puts "Commands are: #{inspect cmds}"
      Process.flag(:trap_exit, true)
      pid = case Counter.start_link() do
        {:ok, c_pid}  -> c_pid
        {:error, {:already_started, _c_pid}} -> :kapputt # c_pid
      end
      {_history, _state, result} = run_commands(__MODULE__, cmds)
      :ok = GenServer.stop(pid, :normal)
      wait_for_stop(pid)
      result == :ok
    end
  end

  ##########################
  ##
  # The pre- and postconditions for executing the model
  #
  ##
  ##########################

  @doc """
  Every call can be made everytime. It is called for generating commands
  and for executing them.
  """
  @spec precondition(state_t, call_t) :: boolean
  def precondition(_state, {:call, _m, _f, _a}), do: true

  @doc "The expected outcome. Only called after executing the command"
  @spec postcondition(state_t, call_t, any) :: boolean
  def postcondition(:init, {:call, _,:inc, _}, _result), do: true
  def postcondition(:init, {:call, _,:clear, _}, _result), do: true
  def postcondition(:init, {:call, _,:get, _}, -1), do: true
  def postcondition(:zero, {:call, _,:clear, _}, _result), do: true
  def postcondition(:zero, {:call, _,:inc, _}, _result), do: true
  def postcondition(:inc, {:call, _,:inc, _}, _result), do: true
  def postcondition(:inc, {:call, _,:clear, _}, _result), do: true
  def postcondition(:zero, {:call, _,:get, _}, 0), do: true
  def postcondition(:one,  {:call, _,:get, _}, result), do: result > 0
  def postcondition(:one, {:call, _,:inc, _}, result) do
    # generate a consistent failure
    # result != 6
    true
  end
  def postcondition(:one, {:call, _,:clear, _}, _result), do: true
  def postcondition(_old_state, {:call, _m, _f, _a}, _result) do
    false
  end

  @doc """
  The next state after being in state `s`, getting `result` of
  a call `c`. We do not care about the result for now.
  """
  @spec next_state(s :: StateM.symbolic_state | StateM.dynamic_state, result :: term,
    c :: StateM.symb_call) :: StateM.symbolic_state |  StateM.dynamic_state
  def next_state(:init, _, {:call, _,:inc, _}), do: :zero
  def next_state(:init, _, {:call, _,:clear, _}), do: :zero
  def next_state(:zero, _, {:call, _,:clear, _}), do: :zero
  def next_state(:zero, _, {:call, _,:inc, _}), do: :one
  def next_state(:one, _, {:call, _,:inc, _}), do: :one
  def next_state(:one, _, {:call, _,:clear, _}), do: :zero
  def next_state(state, _, {:call, _,:get, _}), do: state
  def next_state(state, _, {:call, _,:fail, _}), do: state

  def initial_state(), do: :init

  @doc """
  The commands allowed in every state `_state`. Currently, no
  all commands are allowed in any case.
  """
  def command(_state), do: frequency [
    {10, {:call, Counter, :clear, []}},
    {30, {:call, Counter, :inc, []}},
    {10, {:call, Counter, :get, []}},
    {1, {:call, Counter, :fail, []}}
  ]

  ##########################
  ##
  # The state machine model of the counter
  # It is not integrated into the property testing!
  ##
  ##########################

  @spec init() :: state_t
  def init, do: :init

  @spec clear(state_t) :: state_t
  def clear(_state), do: :zero

  @spec inc(state_t) :: state_t
  def inc(:init), do: :zero
  def inc(_state), do: :one

  @spec get(state_t) :: integer
  def get(:init), do: -1
  def get(:zero), do: 0
  def get(:one), do: 1

end
