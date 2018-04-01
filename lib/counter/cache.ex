defmodule Counter.Cache do
  @moduledoc """
  Implement the basic sequential cache from
  http://propertesting.com/book_stateful_properties.html
  """

  use GenServer

  @cache_name __MODULE__

  def start_link(n) do
    GenServer.start_link(__MODULE__, [n], name: @cache_name)
  end

  def stop(), do: GenServer.stop(__MODULE__)

  @doc """
  Finding keys is done through scanning an ETS table with `:ets.match/2`
  """
  def find(key) do
    case :ets.match(@cache_name, {:"_", {key, :"$1"}}) do
        [[val]] -> {:ok, val}
        [] -> {:error, :not_found}
    end
  end

  @doc """
  Caching overwrites duplicates. If the the table is full, overwrite
  from the start.
  """
  def cache(key,  val) do
    require Logger
    case :ets.match(@cache_name, {:"$1", {key, :"_"}}) do # find dupes
        [[n]] ->
            :ets.insert(@cache_name, {n, {key, val}}) # overwrite dupe
        [] ->
            case :ets.lookup(@cache_name, :count) do # insert new
                [{:count, current, max}] when current >= max ->
                    # table is full, overwrite from the beginning
                    :ets.insert(@cache_name, [{1, {key, val}}, {:count, 1, max}])
                [{:count, current, max}] when current < max ->
                    # add entries incrementally
                    :ets.insert(@cache_name, [{current+1, {key, val}},
                                       {:count, current + 1, max}])
            end
    end
    Logger.debug "Cache.cache(#{inspect key}, #{inspect val})"
    Logger.debug "Cache is: #{inspect :ets.tab2list(@cache_name)}"
  end

  @doc """
  The cache gets flushed by removing all the entries and resetting its counters
  """
  def flush() do
    [{:count, _, max}] = :ets.lookup(@cache_name, :count)
    :ets.delete_all_objects(@cache_name)
    :ets.insert(@cache_name, {:count, 0, max})
  end

  def init(n) do
    :ets.new(@cache_name, [:public, :named_table])
    :ets.insert(@cache_name, {:count, 0, n})
    {:ok, :nostate}
  end

end
