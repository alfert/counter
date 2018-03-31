defmodule CounterModelTest do
  @moduledoc """
  A statemachine testing approach on top of `stream_data`.

  This state machine has three simple states: `:init`, `:zero` and
  `:one`.
  """

  use ExUnit.Case
  use ExUnitProperties
  alias Statemachine, as: SM
  require Logger
  import ExUnit.CaptureLog

  property "find the fail command" do
    assert_raise ExUnit.AssertionError, fn ->
      check all cmds <- StreamData.list_of(command(:one)) do
        assert Enum.all?(cmds, &no_failed_call?/1)
      end
    end
  end

  property "ensure that fail is finally generated" do
    ex = assert_raise ExUnit.AssertionError, fn ->
      check all cmds <- SM.generate_commands(__MODULE__) do
        if Enum.any?(cmds, &failed_call?/1) do
          capture_log(fn -> Logger.error "cmds = #{inspect cmds}" end)
        end
        assert Enum.all?(cmds, &no_failed_call?/1)
      end
    end
    assert ex.message =~ ":fail"
  end

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
  @spec next_state(call :: call_type, state :: state_type)
      :: {Macro.t, state_type}
  def next_state(c = {:call, _,:inc, _}, :init), do:  {the_fun(c), :zero}
  def next_state(c = {:call, _,:clear, _}, :init), do:  {the_fun(c), :zero}
  def next_state(c = {:call, _,:clear, _}, :zero), do:  {the_fun(c), :zero}
  def next_state(c = {:call, _,:inc, _}, :zero), do:  {the_fun(c), :one}
  def next_state(c = {:call, _,:inc, _}, :one), do:  {the_fun(c), :one}
  def next_state(c = {:call, _,:clear, _}, :one), do:  {the_fun(c), :zero}
  def next_state(c = {:call, _,:get, _}, state), do:  {the_fun(c), state}
  # allow fail only in state :one
  def next_state(c = {:call, _,:fail, _}, state = :one), do:  {the_fun(c), state}

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


  defp the_fun({:call, _m, f, _a} ), do: f

end
