defmodule Counter.PropCheck.StateM do

  @callback initial_state() :: any

  use PropCheck

  @type symbolic_state :: any
  @type dynamic_state :: any
  @type state_t :: symbolic_state | dynamic_state
  @type symbolic_var :: {:var, pos_integer}
  @type symbolic_call :: {:call, module, atom, [any]}
  @type command :: {:set, symbolic_var, symbolic_call}
  @type history_element :: {dynamic_state, any}
  @type result_t :: :ok | {:pre_condition, any} | {:post_condition, any} |
    {:exception, any}


  @type t :: %__MODULE__{
    history: [history_element],
    state: state_t,
    result: result_t
  }
  defstruct [
    history: [],
    state: nil,
    result: :ok
  ]

  @doc """
  Generates the command list for the given module
  """
  @spec commands(module) :: PropCheck.BasicTypes.type
  def commands(mod) do
    initial_state = mod.initial_state()
    gen_cmd = sized(size, gen_cmd_list(size, mod, initial_state, 1))
    such_that cmds <- gen_cmd, when: is_valid(mod, initial_state, cmds)
      # let list <-
      #     sized(size, gen_cmd_list(size, mod, initial_state, 1) |> noshrink()) do
      #   shrink_list(list)
      # end
  end

  # TODO: How is this function to be defined?
  def is_valid(mod, initial_state, cmds) do
    true
  end

  @doc """
  The internally used recursive generator for the command list
  """
  @spec gen_cmd_list(pos_integer, module, state_t, pos_integer) :: PropCheck.BasicTypes.type
  def gen_cmd_list(size, mod, state, step_counter) do
    frequency([
      {1, []},
      {size, let call <-
        # TODO: auto-detect the set of commands and select one of them
        (such_that c <- mod.command(state), when: check_precondition(state, c))
        do
          gen_result = {:var, step_counter}
          gen_state = call_next_state(state, call, gen_result)
          let cmds <- gen_cmd_list(size - 1, mod, gen_state, step_counter + 1) do
            [{:set, gen_result, call} | cmds]
          end
        end}
      ])
  end

  ###
  # implement run_commands
  #
  ###
  @spec run_commands([command]) :: t
  def run_commands(commands) do
    commands
    |> Enum.reduce(%__MODULE__{}, fn
      # do nothing if a failure occured
      _cmd, acc = %__MODULE__{result: r} when r != :ok -> acc
      # execute the next command
      cmd, acc ->
        cmd
        |> execute_cmd()
        |> update_history(acc)
    end)
  end

  @spec execute_cmd({state_t, symbolic_call}) :: {state_t, symbolic_call, result_t}
  def execute_cmd({state, c = {:call, m, f, args}}) do
    result = if check_precondition(state, c) do
      try do
        result = apply(m, f, args)
        if check_postcondition(state, c, result) do
          result
        else
          {:post_condition, result}
        end
      rescue exc -> {:exception, exc}
      catch
        value -> {:exception, value}
        kind, value -> {:exception, {kind, value}}
      end
    else
      {:pre_condition, state}
    end
    {state, c, result}
  end

  def update_history(event = {s, _, r}, %__MODULE__{history: h}) do
    %__MODULE__{state: s, result: r, history: [event | h]}
  end

  @spec call_next_state(symbolic_call, state_t, any) :: state_t
  def call_next_state({:call, mod, f, args}, state, result) do
    next_fun = (Atom.to_string(f) <> "_next")
      |> String.to_atom
    apply(mod, next_fun, [state, args, result])
  end

  @spec check_preconditions([{state_t, symbolic_call}]) :: boolean
  def check_preconditions(list) do
    Enum.all?(list, fn {state, call} -> check_precondition(state, call) end)
  end

  @spec check_precondition(state_t, symbolic_call) :: boolean
  def check_precondition(state, {:call, mod, f, args}) do
    pre_fun = (Atom.to_string(f) <> "_pre") |> String.to_atom
    apply(mod, pre_fun, [state, args])
  end

  @spec check_postcondition(state_t, symbolic_call, any) :: any
  def check_postcondition(state,  {:call, mod, f, args}, result) do
    post_fun = (Atom.to_string(f) <> "_post") |> String.to_atom
    apply(mod, post_fun, [state, args, result])
  end


  @doc """
  Detects alls commands within `mod_bin_code`, i.e. all functions with the
  same prefix and a suffix `_command` or `_args` and a prefix `_next`.
  """
  @spec command_list(binary) :: [{:cmd, module, String.t, (state_t -> symbolic_call)}]
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
    |> Enum.filter(fn {f, _a} ->
      MapSet.member?(next_funs, f)
    end)
  end

  @spec all_functions(binary) :: {module, [{String.t, arity}]}
  def all_functions(mod_bin_code) do
    {:ok, {mod, [{:exports, functions}]}} = :beam_lib.chunks(mod_bin_code, [:exports])
    funs = Enum.map(functions, fn {f, a} -> {Atom.to_string(f), a} end)
    {mod, funs}
  end

end
