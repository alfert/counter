defmodule Statemachine do
  @moduledoc """
  Property-based testing or better data generation with a state machine in mind.
  The `fishcakez_unfold`-algorithm is borrowed from @fishcakez.
  """
  alias StreamData.LazyTree
  require Logger

  defstruct [
    history: [],
    state: nil,
    result: :ok
  ]

  def run_commands(mod, commands) do
    commands
    |> Enum.reduce(%__MODULE__{}, fn cmd, acc ->
        cmd
        |> execute_cmd(mod)
        |> update_history(acc)
    end)
    |> Map.put(:result, :ok)
  end

  def execute_cmd({state, c = {:call, m, f, args}}, mod) do
    import ExUnit.Assertions
    assert mod.precondition(state, c)
    result = apply(m, f, args)
    assert mod.postcondition(state, c, result)
    {state, c, result}
  end

  def update_history(event = {s, _, r}, %__MODULE__{history: h}) do
    %__MODULE__{state: s, result: r, history: [event | h]}
  end

  def generate_commands(mod) do
    new(fn seed, size ->
      gen_cmd_list(mod.initial_state(), mod, size, 1, seed)
      |> LazyTree.zip()
      |> LazyTree.map(&command_lazy_tree(&1, 1)) # min size is 1
      |> LazyTree.flatten()
      # this is like list_uniq: filter out invalid values
      |> LazyTree.filter(&check_preconditions(mod, &1))
    end)
  end

  def gen_cmd_list(_state, _mod, 0, _position, _seed), do: []
  def gen_cmd_list(state, mod, size, position, seed) do
    {seed1, seed2} = split_seed(seed)
    # Logger.debug "gen_cmd_list: state is #{inspect state}"
    s = StreamData.constant(state)
    # Logger.debug "gen_cmd_list: s is #{inspect s}"
    tree = StreamData.__call__({s, mod.command(state)}, seed1, size)
    {gen_state, generated_call} = tree.root
    gen_result = {:var, position}
    next_state = mod.next_state(gen_state, gen_result, generated_call)
    [tree | gen_cmd_list(next_state, mod, size - 1, position + 1, seed2)]
  end

  def check_preconditions(mod, list) do
    list
    |> Enum.all?(fn {state, call} -> mod.precondition(state, call) end)
  end

  @spec command_lazy_tree([{state_t, LazyTree.t}], non_neg_integer) :: LazyTree.t
  defp command_lazy_tree(list, min_length) do
    length = length(list)

    if length == min_length do
      lazy_tree_constant(list)
    else
      # in contrast to lists we shrink from the end
      # towards the front and have a minimum list of 1
      # element: The initial command.
      children =
        Stream.map((length - 1)..1, fn index ->
          command_lazy_tree(List.delete_at(list, index), min_length)
        end)

      lazy_tree(list, children)
    end
  end

  ##########
  ## Borrowed from StreamData
  @type state_t :: any

  defp new(generator) when is_function(generator, 2) do
    %StreamData{generator: generator}
  end

  defp lazy_tree(root, children) do
    %LazyTree{root: root, children: children}
  end

  defp lazy_tree_constant(term) do
    %LazyTree{root: term}
  end

  if String.to_integer(System.otp_release()) >= 20 do
    @rand_algorithm :exsp
  else
    @rand_algorithm :exs64
  end
  defp split_seed(seed) do
    {int, seed} = :rand.uniform_s(1_000_000_000, seed)
    new_seed = :rand.seed_s(@rand_algorithm, {int, 0, 0})
    {new_seed, seed}
  end
  ## END of borrowed functions
  ######################

  # This is pseudo-code of PropEr's approach
  # def proper_commands(mod) do
  #   let initial_state <- mod.initial_state() do
  #     such_that cmds <-
  #       let list <- proper_sized(size,
  #                       no_shrink(proper_commands(size, mod, initial_state, 1)) do
  #          proper_shrink_list(list)
  #       end, when: proper_is_valid(mod, initial_state, cmds),
  #     do: cmds
  #   end
  # end
  # def proper_commands(size, mod, state, position) when size > 1 do
  #   let call <-
  #     such_that x <- mod.command(state), when: mod.pre(x, state) do
  #       var = {:var, position}
  #       next_state = mod.next_state(state, var, call)
  #       let cmds <- commands(size-1, mod, next_state, position + 1) do
  #         [{:set, var, call} | cmds]
  #       end
  #     end
  # end

end
