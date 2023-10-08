defmodule Graph do
  defstruct vertices: MapSet.new(), edges: %{}, metadata: %{edges: %{}}

  def new, do: %__MODULE__{}

  def edges(%__MODULE__{edges: edges}), do: edges
  def vertices(%__MODULE__{vertices: vertices}), do: vertices

  def add_vertex(%__MODULE__{vertices: vertices} = graph, vertex) do
    if MapSet.member?(vertices, vertex) do
      graph
    else
      vertices = MapSet.put(vertices, vertex)
      %__MODULE__{graph | vertices: vertices}
    end
  end

  def add_edge(%__MODULE__{} = graph, v1, v2) do
    add_edge(graph, v1, v2, [])
  end

  def add_edge(
        %__MODULE__{edges: edges, metadata: %{edges: edge_metadata} = graph_metadata} = graph,
        v1,
        v2,
        metadata
      ) do
    graph =
      graph
      |> add_vertex(v1)
      |> add_vertex(v2)

    edges = Map.update(edges, v1, MapSet.new([v2]), &MapSet.put(&1, v2))
    edge_metadata = Map.update(edge_metadata, {v1, v2}, [metadata], &[metadata | &1])

    %__MODULE__{graph | edges: edges, metadata: %{graph_metadata | edges: edge_metadata}}
  end

  def direct_children(%__MODULE__{edges: edges}, vertex) do
    Map.get(edges, vertex, MapSet.new())
  end

  def transitive_children(
        %__MODULE__{} = graph,
        vertex,
        traversed_vertices \\ MapSet.new()
      ) do
    direct_children = direct_children(graph, vertex)

    traversed_vertices =
      [vertex]
      |> MapSet.new()
      |> MapSet.union(traversed_vertices)

    direct_children
    |> MapSet.difference(traversed_vertices)
    |> Enum.reduce(MapSet.new(), fn child, acc ->
      transitive_deps = transitive_children(graph, child, traversed_vertices)
      MapSet.union(acc, transitive_deps)
    end)
    |> MapSet.union(direct_children)
  end

  def path_to(%__MODULE__{} = graph, parent, child) do
    child in transitive_children(graph, parent)
  end

  def path_to?(%__MODULE__{} = graph, parent, child) do
    child in transitive_children(graph, parent)
  end

  def to_dot(%__MODULE__{} = graph, path) do
    dot = to_dot(graph)

    File.write!(path, dot, [:write])
  end

  def to_dot(%__MODULE__{edges: edges, vertices: vertices}) do
    grouped_vertices =
      vertices
      |> Enum.sort()
      |> Enum.group_by(fn {module, _name, _arity} -> module end)

    subgraphs =
      grouped_vertices
      |> Enum.map(fn {module, mfas} ->
        nodes =
          mfas
          |> Enum.map(&vertex_name/1)
          |> Enum.map(fn str -> ["\t", str, "\n"] end)

        {module, nodes}
      end)
      |> Enum.map(fn {module, nodes} ->
        [
          [~s(subgraph "#{inspect(module)}" {\n)],
          [~s(label="#{inspect(module)}")],
          nodes,
          ["}\n"]
        ]
      end)

    edge_lines =
      Enum.map(edges, fn {vertex, direct_children} ->
        Enum.map(direct_children, fn child ->
          ["\t", vertex_name(vertex), " -> ", vertex_name(child), "\n"]
        end)
      end)

    [
      [~s(digraph {\n)],
      subgraphs,
      edge_lines,
      ["}\n"]
    ]
  end

  defp vertex_name({module, function, arity}) do
    ~s("#{inspect(module)}.#{function}/#{arity}")
  end

  defp vertex_name(module) do
    ~s("#{inspect(module)}")
  end
end
