defmodule Counter.StateM do
  @moduledoc """
  Provides the API of `eqc_statem` with the grouped functions.
  """

  alias StreamData.LazyTree
  use ExUnitProperties
  require Logger

  @type gen_fun_t :: (state_t -> StreamData.LazyTree.t)
  @type cmd_t ::
    {:args, module, String.t, atom, gen_fun_t} |
    {:cmd, module, String.t, gen_fun_t}

  defstruct [
    history: [],
    state: nil,
    result: :ok
  ]

  def run_commands(commands) do
    commands
    |> Enum.reduce(%__MODULE__{}, fn cmd, acc ->
        cmd
        |> execute_cmd()
        |> update_history(acc)
    end)
    |> Map.put(:result, :ok)
  end

  def execute_cmd({state, c = {:call, m, f, args}}) do
    import ExUnit.Assertions
    assert call_precondition(state, c)
    result = apply(m, f, args)
    assert call_postcondition(state, c, result)
    {state, c, result}
  end

  def update_history(event = {s, _, r}, %__MODULE__{history: h}) do
    %__MODULE__{state: s, result: r, history: [event | h]}
  end


  def commands(mod) when is_atom(mod) do
    raise "Ouch, need a macro here to found _CALLER__.filename"
  end
  def commands(mod, mod_bin_code) do
    mod_bin_code
    |> command_list()
    |> generate_commands(mod)
  end

  def command_list(mod_bin_code) do
    {mod, all_funs} = all_functions(mod_bin_code)
    cmd_impls = find_commands(mod_bin_code)

    cmd_impls
    |> Enum.map(fn {cmd, _arity} ->
      if find_fun(all_funs, "_args", [1]) do
        args_fun = fn state -> apply(mod, String.to_atom(cmd <> "_args"), [state]) end
        args = gen_call(mod, String.to_atom(cmd), args_fun)
        {:cmd, mod, cmd, args}
      else
        {:cmd, mod, cmd, & apply(mod, String.to_atom(cmd <> "_command"), &1)}
      end
    end)
  end

  @doc """
  Generates a function, which expects a state to create the call tuple
  with constants for module and function and an argument generator.
  """
  def gen_call(mod, fun, arg_fun) when is_atom(fun) and is_function(arg_fun, 1) do
    fn state ->  {:call, mod, fun, arg_fun.(state)} end
  end


  @spec find_fun([{String.t, arity}], String.t, [arity]) :: boolean
  def find_fun(all, suffix, arities) do
    all
    |> Enum.find_index(fn {f, a} ->
      a in arities and String.ends_with?(f, suffix)
    end)
    |> is_integer()
  end

  @spec find_commands(binary) :: [{String.t, arity}]
  def find_commands(mod_bin_code) do
    {_mod, funs} = all_functions(mod_bin_code)
    next_funs = funs
    |> Stream.filter(fn {f, a} ->
      String.ends_with?(f, "_next") and (a in [3,4]) end)
    |> Stream.map(fn {f, _a} -> String.replace_suffix(f, "_next", "") end)
    |> MapSet.new()
    funs
    |> Enum.filter(fn {f, a} ->
      MapSet.member?(next_funs, f) 
    end)
  end

  @spec all_functions(binary) :: {module, [{String.t, arity}]}
  def all_functions(mod_bin_code) do
    {:ok, {mod, [{:exports, functions}]}} = :beam_lib.chunks(mod_bin_code, [:exports])
    funs = Enum.map(functions, fn {f, a} -> {Atom.to_string(f), a} end)
    {mod, funs}
  end


  @spec generate_commands(Enum.t, module) :: StreamData.LazyTree.t
  def generate_commands(cmd_list, mod) do
    Logger.debug "generate_commands: cmd_list = #{inspect cmd_list}"
    new(fn seed, size ->
      gen_cmd_list(mod.initial_state(), mod, cmd_list, size, 1, seed)
      |> LazyTree.zip()
      |> LazyTree.map(&command_lazy_tree(&1, 1)) # min size is 1
      |> LazyTree.flatten()
      # this is like list_uniq: filter out invalid values
      |> LazyTree.filter(&check_preconditions(&1))
    end)
  end

  def gen_cmd_list(_state, _mod, _cmd_list, 0, _position, _seed), do: []
  def gen_cmd_list(state, mod, cmd_list, size, position, seed) do
    {seed1, seed2} = split_seed(seed)
    Logger.debug "gen_cmd_list: state is #{inspect state}"
    s = StreamData.constant(state)

    calls = cmd_list
    |> Enum.map(fn {:cmd, _mod, _f, arg_fun} -> arg_fun.(state) end)
    |> fn l ->
      Logger.debug("call list is #{inspect l}")
      l end.()
    |> one_of() # TODO: check for frequencies here!

    tree = StreamData.__call__({s, calls}, seed1, size)
    {gen_state, generated_call} = tree.root
    Logger.debug "generated_call is: #{inspect generated_call}"
    if call_precondition(gen_state, generated_call) do
      gen_result = {:var, position}
      next_state = call_next_state(generated_call, gen_state, gen_result)
      [tree | gen_cmd_list(next_state, mod, cmd_list, size - 1, position + 1, seed2)]
    else
      gen_cmd_list(state, mod, cmd_list, size, position, seed2)
    end
  end

  def call_next_state({:call, mod, f, args}, state, result) do
    next_fun = (Atom.to_string(f) <> "_next")
      |> String.to_atom
    apply(mod, next_fun, [state, args, result])
  end


  def check_preconditions(list) do
    Enum.all?(list, fn {state, call} -> call_precondition(state, call) end)
  end

  def call_precondition(state, {:call, mod, f, args}) do
    pre_fun = (Atom.to_string(f) <> "_pre") |> String.to_atom
    apply(mod, pre_fun, [state, args])
  end

  def call_postcondition(state,  {:call, mod, f, args}, result) do
    post_fun = (Atom.to_string(f) <> "_post") |> String.to_atom
    apply(mod, post_fun, [state, args, result])
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

end
