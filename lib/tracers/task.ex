defmodule Tracers.Task do
  @typedoc """
  `option_switches` is anything that can be accepted by `OptionParser.parse(args, strict: option_switches)`
  """
  alias Mix.Task.Compiler
  alias Mix.Task.Compiler.Diagnostic

  @type postcompile_status :: {Compiler.status(), [Diagnostic.t()]}

  @type option_switches :: Keyword.t()
  @callback precompile(option_switches()) :: term
  @callback postcompile(postcompile_status(), option_switches()) :: postcompile_status()

  defmacro __using__(args) do
    option_switches = Keyword.get(args, :option_switches, [])

    quote do
      use Mix.Task
      @behaviour unquote(__MODULE__)
      @behaviour Tracers.Tracer

      def run(args) do
        unquote(__MODULE__).run(args, __MODULE__, unquote(option_switches))
      end
    end
  end

  def run(args, mod, option_switches) do
    {opts, _, _} = OptionParser.parse(args, strict: option_switches)

    mod.precompile(opts)

    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [mod | tracers])

    Mix.Task.Compiler.after_compiler(:app, fn status -> mod.postcompile(status, opts) end)

    {:ok, []}
  end
end
