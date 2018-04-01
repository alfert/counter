defmodule TestCounterCache do


  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM

  require Logger
  import ExUnit.CaptureLog

  alias Counter.Cache


  @cache_size 10

  property "run the buggy cache" do
    forall cmds <- commands(__MODULE__) do
      Cache.start_link(@cache_size)
      {history, state, result} = run_commands(__MODULE__, cmds)
      Cache.stop()
      (result == :ok)
              |> when_fail(
                  IO.puts """
                  History: #{inspect history, pretty: true}
                  State: #{inspect state, pretty: true}
                  Result: #{inspect result, pretty: true}
                  """)
              |> aggregate(command_names cmds)
              |> collect(length cmds)
    end
  end

  ###########################

  # the state for testing (= the model)
  defstruct [max: @cache_size, entries: [], count: 0]

  def initial_state(), do: %__MODULE__{}

  def command(_) do
    frequency([
        {1, {:call, Cache, :find, [key()]}},
        {3, {:call, Cache, :cache, [key(), val()]}},
        {1, {:call, Cache, :flush, []}}
    ])
  end

  # Generators for keys and values

  @doc """
  Keys are chosen from a set of reusable keys and some arbitrary keys.

  The generator for keys is designed to allow some keys to be repeated
  multiple time. By using a restricted set of keys (with the `integer/1 generator)
  along with a much wider one, the generator should help exercising any
  code related to key reuse or matching, but without losing the ability
  to 'fuzz' the system.
  """
  def key(), do: oneof([
    range(1, @cache_size),
    integer()
    ])
  @doc "our values are integers"
  def val(), do: integer()

  @doc """
  Picks whether a command should be valid under the current state:
  don't flush an empty cache for no reason.
  """
  # def precondition(%__MODULE__{count: 0}, {:call, Cache, :flush, []}), do: false
  def precondition(%__MODULE__{}, {:call, _mod, _fun, _args}), do: true

  @doc """
  Assuming the postcondition for a call was true, update the model
  accordingly for the test to proceed.
  """
  def next_state(state, _res, {:call, Cache, :flush, _}) do
    update_entries(state, [])
  end
  def next_state(s=%__MODULE__{entries: l, count: n, max: m}, _res,
           {:call, Cache, :cache, [k, v]}) do
    case List.keyfind(l, k, 0, false) do
        # When the cache is at capacity, the first element is dropped (tl(L))
        # before adding the new one at the end
        false when n == m -> update_entries(s, tl(l) ++ [{k, v}])
        # When the cache still has free place, the entry is added at the end,
        # and the counter incremented
        false when n < m  -> update_entries(s, l ++ [{k, v}])
        # If the entry key is a duplicate, it replaces the old one without refreshing it
        {k, _}            -> update_entries(s, List.keyreplace(l, k, 0, {k, v}))
    end
  end
  def next_state(state, _res, {:call, _mod, _fun, _args}), do: state

  defp update_entries(s = %__MODULE__{}, l) do
    %__MODULE__{s | entries: l, count: Enum.count(l)}
  end


  @doc """
  Given the state `state` *prior* to the call `{call, mod, fun, args}`,
  determine whether the result `res` (coming from the actual system)
  makes sense.
  """
  def postcondition(%__MODULE__{entries: l}, {:call, Cache, :find, [key]}, res) do
    case List.keyfind(l, key, 0, false) do
        false      -> res == {:error, :not_found}
        {^key, val} -> res == {:ok, val}
    end
  end
  def postcondition(_state, {:call, _mod, _fun, _args}, _res), do: true

end
