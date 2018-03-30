import TypeClass
defmodule Counter.PropCheck.ShrinkTree do
  @moduledoc """
  The `ShrinkTree` is a lazy tree, implementing the `Functor` typeclass.

  It stores a counter example in its root and has (potentially) infinite
  many children, which shrink the parents counter example. Structurally,
  this is a Rose-Tree, c.f. `Algae.Tree.Rose` and we follow their naming.
  """
  import Algae

  @type rose :: any
  @type forest :: Enum.t

  defdata do
    rose :: any
    forest :: Enum.t \\ []
  end

  @doc """
  A lazy definition of shrink tree. The parameter `shrink_stream` is
  a stream generating function, i.e. the shrinking strategy for a
  given type. It returns a function, which takes a fresh root and
  applies this root to `shrink_stream` such that a lazy enumerable of
  shrink values is computed.
  """
  def build_tree_fun(shrinker_fun) do
    fn root ->
      new(root,
        shrinker_fun.(root)
        |> Stream.map(build_tree_fun(shrinker_fun))
        )
    end

  end

  @doc """
  Joins two shrink trees, i.e. from two joint generators, such
  that ?????
  """
  def join(tree, root, shrinklist) do
    nil
  end

end
alias Counter.PropCheck.ShrinkTree

defimpl TypeClass.Property.Generator, for: Counter.PropCheck.ShrinkTree do
  def generate(_) do
    case Enum.random(0..2) do
      0 -> ShrinkTree.new(rose(), forest())
      _ -> ShrinkTree.new(rose())
    end
  end

  def forest do
    fn ->
      case Enum.random(0..10) do
        0 -> ShrinkTree.new(rose(), forest())
        _ -> ShrinkTree.new(rose())
      end
    end
    |> Stream.repeatedly()
    |> Enum.take(Enum.random(0..5))
  end

  def rose do
    [1, 1.1, "", []]
    |> Enum.random()
    |> TypeClass.Property.Generator.generate()
  end
end

definst Witchcraft.Functor, for: ShrinkTree do
  alias Witchcraft.Functor
  def map(%ShrinkTree{rose: rose, forest: forest}, fun) do
    %ShrinkTree{
      rose:   fun.(rose),
      forest: Functor.map(forest, &Functor.map(&1, fun))
    }
  end
end
