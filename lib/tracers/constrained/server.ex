defmodule Tracers.Constrained.Server do
  use GenServer

  require Tracers.Constrained.ModuleTypes

  alias Tracers.Constrained.ModuleTypes
  alias Tracers.Constrained.Table

  @types_table :module_types
  @dependencies_table :dependencies

  def start_link(server_name \\ __MODULE__) when is_atom(server_name) do
    GenServer.start_link(__MODULE__, {server_name}, name: server_name)
  end

  def init({server_name}) when is_atom(server_name) do
    server_name
    |> qualified_table_name(@types_table)
    |> Table.from_name()
    |> Table.create()

    server_name
    |> qualified_table_name(@dependencies_table)
    |> Table.from_name()
    |> Table.create()

    {:ok, {}}
  end

  def module_type(server_name, module) do
    table =
      server_name
      |> qualified_table_name(@types_table)
      |> Table.from_name()

    case Table.lookup_one(table, module) do
      nil ->
        false

      {_module, type} ->
        type
    end
  end

  def module_type_declared(server_name, type, env) do
    table =
      server_name
      |> qualified_table_name(@types_table)
      |> Table.from_name()

    case Table.lookup_one(table, env.module) do
      nil ->
        Table.insert(table, {env.module, type})

      {module, :undefined} ->
        Table.insert(table, {module, type})

      {_module, old_type} when ModuleTypes.is_module_type(type) ->
        raise "Module #{env.module} is redefining its type from #{old_type} to #{type}"

      {module, undefined_type} ->
        raise "#{module} has an illegal type: #{undefined_type}"
    end

    :ok
  end

  def function_dependency(server_name, {module, function, arity}, env) do
    case env.function do
      {caller_function, caller_arity} ->
        record = {
          {env.module, caller_function, caller_arity},
          {module, function, arity},
          {env.file, env.line}
        }

        server_name
        |> qualified_table_name(@dependencies_table)
        |> Table.from_name()
        |> Table.insert(record)

        :ok

      _ ->
        :ok
    end
  end

  def analyze(server_name) do
    functions_graph =
      server_name
      |> qualified_table_name(@dependencies_table)
      |> Table.from_name()
      |> Table.reduce(Graph.new(), &build_graph/2)

    modules_graph = modules_graph(functions_graph)

    forbidden_dependencies =
      server_name
      |> qualified_table_name(@types_table)
      |> Table.from_name()
      |> Table.reduce([], fn {module, type}, acc ->
        forbidden_dependencies =
          :tracers
          |> Application.get_env(type)
          |> Keyword.get(:forbidden_dependencies, [])

        case verify_forbidden_dependencies(
               module,
               forbidden_dependencies,
               functions_graph,
               modules_graph
             ) do
          :ok ->
            acc

          {:error, {:forbidden_dependencies, deps}} ->
            [{module, deps} | acc]
        end
      end)

    case forbidden_dependencies do
      [] ->
        :ok

      [_ | _] ->
        reason = {:forbidden_dependencies, forbidden_dependencies}
        Mix.shell().info([severity(:error), error_message(reason), "\n"])
        {:error, reason}
    end
  end

  defp error_message({:forbidden_dependencies, modules}) do
    modules =
      modules
      |> List.flatten()
      |> Enum.map(fn {module, forbidden_dependencies} ->
        "#{inspect(module)} -> #{inspect(forbidden_dependencies)}"
      end)
      |> Enum.map(&("* " <> &1))
      |> Enum.join("\n\t")
      |> IO.inspect(label: "Joined")

    ~s(The following forbidden dependencies were found:\n\t#{modules}
    \nPlease remove forbidden dependencies from these modules.)
  end

  defp severity(severity), do: [:bright, color(severity), "#{severity}: ", :reset]
  defp color(:error), do: :red
  # defp color(:warning), do: :yellow

  def verify_forbidden_dependencies(
        module,
        forbidden_dependencies,
        _functions_graph,
        modules_graph
      ) do
    discovered_forbidden_deps =
      Enum.filter(forbidden_dependencies, fn forbidden_dependency ->
        Graph.path_to?(modules_graph, module, forbidden_dependency)
      end)

    case discovered_forbidden_deps do
      [] ->
        :ok

      [_ | _] ->
        {:error, {:forbidden_dependencies, discovered_forbidden_deps}}
    end
  end

  def pure?(module, graph) do
    not Graph.path_to?(graph, module, Ecto.Repo.Schema) and
      not Graph.path_to?(graph, module, Ecto.Changeset) and
      not Graph.path_to?(graph, module, Ecto.Query)
  end

  def qualified_table_name(server_name, table_name)
      when is_atom(server_name) and is_atom(table_name) do
    :"$#{server_name}-#{table_name}"
  end

  def build_graph({caller, callee}, graph) do
    Graph.add_edge(graph, caller, callee)
  end

  def build_graph({caller, callee, {_file, _line_number} = meta}, graph) do
    Graph.add_edge(graph, caller, callee, meta)
  end

  def modules_graph(functions_graph) do
    modules_graph =
      Enum.reduce(functions_graph.vertices, Graph.new(), fn {module, _function, _arity}, graph ->
        Graph.add_vertex(graph, module)
      end)

    Enum.reduce(
      functions_graph.edges,
      modules_graph,
      fn {{caller_module, _caller_function, _caller_arity}, deps}, graph ->
        Enum.reduce(deps, graph, fn {called_module, _called_function, _called_arity}, graph ->
          Graph.add_edge(graph, caller_module, called_module)
        end)
      end
    )
  end
end
