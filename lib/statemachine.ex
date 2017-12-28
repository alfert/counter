defmodule Statemachine do
  @moduledoc """
  Property-based testing or better data generation with a state machine in mind.
  The `fishcakez_unfold`-algorithm is borrowed from @fishcakez.
  """

  ###############
  #
  # Modify StreamData.call_n_times and StreamData.list_of to
  # take a reducer-like data generator. Copy and modify
  # it here is adequate, since only new() and split_seed() is privately
  # called.
  #
  #
  ###############
  alias StreamData.LazyTree
  # initial_state() :: state_t,
  # call_gen(state_t) :: {call_t},
  # next_state(state_t, call_t) :: state
  def list_of(initial_state, call_gen, next_state, options \\ []) do
    list_length_range_fun = list_length_range_fun(options)

    new(fn seed, size ->
      {seed1, seed2} = split_seed(seed)
      min_length.._ = length_range = list_length_range_fun.(size)
      length = uniform_in_range(length_range, seed1)

      initial_state
      |> call_n_times(call_gen, next_state, seed2, size, length, [])
      |> LazyTree.zip()
      |> LazyTree.map(&list_lazy_tree(&1, min_length))
      |> LazyTree.flatten()
    end)
  end
  defp call_n_times(_data, _call_gen, _next_state, _seed, _size, 0, result), do: result
  defp call_n_times(state, call_gen, next_state, seed, size, length, result) do
    {seed1, seed2} = split_seed(seed)
    data = call_gen.(state)
    {_call, new_state} = data |> Enum.take(1) |> hd() |> next_state.(state)
    call_n_times(new_state, call_gen, next_state, seed2, size, length - 1,
      [StreamData.__call__(data, seed1, size) | result])
  end
  # original version
  defp call_n_times(_data, _seed, _size, 0, acc), do: acc
  defp call_n_times(data, seed, size, length, acc) do
    {seed1, seed2} = split_seed(seed)
    call_n_times(data, seed2, size, length - 1,
      [StreamData.__call__(data, seed1, size) | acc])
  end

  @spec unfold(acc_t, (acc_t -> {StreamData.t(data_t), acc_t})) :: StreamData.t([data_t]) when acc_t: var, data_t: var
  def unfold(next_acc, next_fun, options \\ []) do
    list_length_range_fun = list_length_range_fun(options)
    new(fn seed, size ->
      {seed1, seed2} = split_seed(seed)
      min_length.._ = length_range = list_length_range_fun.(size)
      length = uniform_in_range(length_range, seed1)

      next_acc
      |> do_unfold(next_fun, seed2, size, length, [])
      |> LazyTree.zip()
      |> LazyTree.map(&list_lazy_tree(&1, min_length))
      |> LazyTree.flatten()
    end)
  end
  def do_unfold(_next_acc, _next_fun, _seed, _size, 0, result), do: result
  def do_unfold(next_acc, next_fun, seed, size, length, result) do
    {seed1, seed2} = split_seed(seed)
    {new_acc, data} = next_fun.(next_acc)
    do_unfold(new_acc, next_fun, seed2, size, length - 1,
      [StreamData.__call__(data, seed1, size) | result])
  end

  def my_list_of(data, options \\ []) do
    unfold(nil, fn _ -> {nil, data} end, options)
  end


  # all private functions from here on are copies from stream_data
  @rand_algorithm :exsp
  defp new(gen), do: %StreamData{generator: gen}
  defp split_seed(seed) do
    {int, seed} = :rand.uniform_s(1_000_000_000, seed)
    new_seed = :rand.seed_s(@rand_algorithm, {int, 0, 0})
    {new_seed, seed}
  end
  defp uniform_in_range(left..right, seed) when left <= right do
    {random_int, _seed} = :rand.uniform_s(right - left + 1, seed)
    random_int - 1 + left
  end
  defp uniform_in_range(left..right, seed) when left > right do
    uniform_in_range(right..left, seed)
  end
  defp lazy_tree_constant(term), do: %LazyTree{root: term}
  defp lazy_tree(root, children), do: %LazyTree{root: root, children: children}

  # copy from stream_data
  defp list_length_range_fun(options) do
    {min, max} =
      case Keyword.fetch(options, :length) do
        {:ok, length} when is_integer(length) and length >= 0 ->
          {length, length}

        {:ok, min..max} when min >= 0 and max >= 0 ->
          {min(min, max), max(min, max)}

        {:ok, other} ->
          raise ArgumentError,
                ":length must be a positive integer or a range " <>
                  "of positive integers, got: #{inspect(other)}"

        :error ->
          min_length = Keyword.get(options, :min_length, 0)
          max_length = Keyword.get(options, :max_length, :infinity)

          unless is_integer(min_length) and min_length >= 0 do
            raise ArgumentError,
                  ":min_length must be a positive integer, got: #{inspect(min_length)}"
          end

          unless (is_integer(max_length) and max_length >= 0) or max_length == :infinity do
            raise ArgumentError,
                  ":max_length must be a positive integer, got: #{inspect(max_length)}"
          end

          {min_length, max_length}
      end

    fn size -> min..(max |> min(size) |> max(min)) end
  end

  # copy from stream_data
  defp list_lazy_tree(list, min_length) do
    length = length(list)

    if length == min_length do
      lazy_tree_constant(list)
    else
      children =
        0..(length - 1)
        |> Stream.map(&List.delete_at(list, &1))
        |> Stream.map(&list_lazy_tree(&1, min_length))

      lazy_tree(list, children)
    end
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
