defmodule Mix.Tasks.Compile.Constrained do
  use Tracers.Task, []

  alias Mix.Task.Compiler.Diagnostic
  alias Tracers.Constrained.Server
  alias Tracers.Constrained.Tracer

  @server_name __MODULE__

  @impl true
  def precompile(_opts) do
    Server.start_link(@server_name)
  end

  @impl true
  def postcompile(_status, _opts) do
    case Server.analyze(@server_name) do
      :ok ->
        {:ok, []}

      {:error, {:forbidden_dependencies, modules} = reason} ->
        {:error,
         [
           %Diagnostic{
             compiler_name: inspect(__MODULE__),
             details: reason,
             file: "unknown",
             message: "The following files have forbidden_dependencies: #{inspect(modules)}",
             position: 0,
             severity: :error
           }
         ]}
    end
  end

  @impl true
  def trace(event, env) do
    Tracer.trace(event, env, @server_name)
  end
end
