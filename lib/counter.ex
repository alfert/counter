defmodule Counter do
  @moduledoc """
  An `Agent`-based counter as an example for a stateful system.
  """

  use Agent

  @spec start_link() :: {:ok, pid}
  @spec start_link(atom) :: {:ok, pid}
  def start_link(name \\ __MODULE__) do
    Agent.start_link(fn -> -1 end, name: name)
  end

  @spec clear() :: :ok
  @spec clear(pid) :: :ok
  def clear(pid \\ __MODULE__) do
    Agent.update(pid, fn _ -> 0 end)
  end

  @spec get() :: integer
  @spec get(pid) :: integer
  def get(pid \\ __MODULE__) do
    Agent.get(pid, fn state -> state end)
  end

  @spec inc() :: :integer
  @spec inc(pid) :: :integer
  def inc(pid \\ __MODULE__) do
    Agent.get_and_update(pid, fn state ->
      new_state = state + 1
      {new_state, new_state}
    end)
  end
end
