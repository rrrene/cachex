defmodule Cachex.Macros do
  @moduledoc false
  # Provides a number of Macro utilities to make it more convenient to write new
  # Macros. This module is a parent of various submodules which provide Macros
  # for specific uses (to avoid bloating requires and imports). I'm pretty new
  # to Macros so if anything in here (or in submodules) can be done more efficiently,
  # feel free to suggest.

  # add various aliases
  alias Cachex.Util

  @doc """
  Fetches the name and arguments from a given function and returns them inside a
  tuple. We use `Macro.decompose_call/1` under the hood to do this.
  """
  def name_and_args(head) do
    head
    |> short_head
    |> Macro.decompose_call
  end

  # We use this to normalize functions with/without guards
  defp short_head({ :when, _, [head | _] }), do: head
  defp short_head(head), do: head

  @doc """
  Trim all defaults from a set of arguments - this is requried in case we want
  to pass arguments through to another function.
  """
  def trim_defaults(args) do
    Enum.map(args, fn(arg) ->
      case elem(arg, 0) do
        :\\ ->
          arg
          |> Util.last_of_tuple
          |> List.first
        _at ->
          arg
      end
    end)
  end

end
