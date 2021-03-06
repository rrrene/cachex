defmodule Mix.Tasks.Cachex.Coveralls do
  # inherit mix
  use Mix.Task

  @moduledoc false
  # A small binding module for running coverage - spinning up and slave nodes as
  # required for remote testing. Providing a Mix task for this means that the
  # user doesn't have to care about setting up any node instances.

  @doc """
  Binds all slave nodes and starts off the `coveralls` task.
  """
  @spec run(OptionParser.argv) :: no_return
  def run(args),
  do: Mix.Cachex.run_in_context("coveralls", args)

  # Detail binding
  defmodule Detail do
    # inherit mix
    use Mix.Task

    @moduledoc false
    # A small binding module for generating detailed coverage reports with bound
    # nodes.

    @doc """
    Binds all slave nodes and starts off the `coveralls.detail` task.
    """
    @spec run(OptionParser.argv) :: no_return
    def run(args),
    do: Mix.Cachex.run_in_context("coveralls.detail", args)

  end

  # HTML binding
  defmodule Html do
    # inherit mix
    use Mix.Task

    @moduledoc false
    # A small binding module for generating HTML coverage reports with bound nodes.

    @doc """
    Binds all slave nodes and starts off the `coveralls.html` task.
    """
    @spec run(OptionParser.argv) :: no_return
    def run(args),
    do: Mix.Cachex.run_in_context("coveralls.html", args)

  end

  # Travis binding
  defmodule Travis do
    # inherit mix
    use Mix.Task

    @moduledoc false
    # A small binding module for generating CI coverage reports with bound nodes.

    @doc """
    Binds all slave nodes and starts off the `coveralls.travis` task.
    """
    @spec run(OptionParser.argv) :: no_return
    def run(args),
    do: Mix.Cachex.run_in_context("coveralls.travis", args)

  end

end
