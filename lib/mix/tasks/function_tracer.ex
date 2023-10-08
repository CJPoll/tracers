defmodule Mix.Tasks.Tracer.Function do
  use Tracers.Task, gen_pdf: :boolean

  @table_name :function_deps
  # @ignore_applications [
  #  :ecto,
  #  :elixir,
  #  :erlang,
  #  :kernel,
  #  :logger,
  #  :stdlib,
  #  :undefined
  # ]
  @ignore_patterns [
    ~r/^Elixir.Ecto/,
    ~r/^Elixir.Phoenix/,
    ~r/^Elixir.Plug/,
    ~r/^Elixir.String/,
    ~r/^Elixir.SharedDb/
  ]

  @ignore_modules [
    File,
    Process,
    Application,
    CSV,
    Confex,
    Base,
    :maps,
    :erlang,
    Poison,
    Jason,
    :elixir,
    :ets,
    :rand,
    :timer,
    Atom,
    Access,
    Macro,
    Macro.Env,
    IO,
    DateTime,
    NaiveDateTime,
    Path,
    Plug.Conn,
    List,
    Logger,
    Flow,
    Enum,
    Kernel,
    Map,
    URI,
    Agent,
    Date,
    DateTime,
    NaiveDateTime,
    Timex,
    String,
    Phoenix,
    Ecto,
    Datadog,
    String.Chars,
    Ecto.Changeset,
    Ecto.Query,
    Ecto.Query.Builder,
    Keyword,
    Regex,
    System,
    Logger.App,
    Phoenix.Controller,
    Timex
  ]

  def precompile(_opts) do
    :ets.new(@table_name, [:named_table, :public])
  end

  def trace({:local_function, meta, name, arity}, env) do
    trace({:remote_function, meta, env.module, name, arity}, env)
  end

  def trace({:remote_function, _meta, module, name, arity} = data, env) do
    IO.inspect("Remote function call detected")

    if should_record_function({module, name, arity}, env) do
      do_trace(data, env)
    else
      :ok
    end

    # with app when app not in @ignore_applications <- :application.get_application(module),
    #     m when m not in @ignore_modules <- module,
    #     module_string <- Atom.to_string(module),
    #     false <-
    #       Enum.any?(@ignore_patterns, fn pattern -> Regex.match?(pattern, module_string) end) do
    #  do_trace(data, env)
    #  :ok
    # else
    #  _ -> :ok
    # end
  end

  def trace(_, _) do
    :ok
  end

  defp should_record_function({module, _name, _arity}, env) do
    caller_in_application?(env, "core") &&
      not module_ignored_by_patterns?(module, @ignore_patterns) &&
      not blacklisted?(module, @ignore_modules)
  end

  defp blacklisted?(module, ignored_modules) do
    module in ignored_modules
  end

  defp module_ignored_by_patterns?(module, regexes) do
    Enum.any?(regexes, fn regex ->
      Regex.match?(regex, module |> Atom.to_string())
    end)
  end

  defp caller_in_application?(env, app) do
    case String.split(env.file, "/") do
      ["", "home", "cjpoll", "dev", "devwork", "juno", "apps", application | _] ->
        application == app

      _ ->
        false
    end
  end

  def do_trace({:remote_function, _meta, module, name, arity}, env) do
    case env.function do
      {caller_function, caller_arity} ->
        data = {{{env.module, caller_function, caller_arity}, {module, name, arity}}}

        :ets.insert(@table_name, data)

        :ok

      _ ->
        :ok
    end
  end

  def postcompile({:ok, diagnostics}, opts) do
    graph = :ets.foldl(&reduce/2, Graph.new(), @table_name)

    :ok = analyze(graph, opts)

    {:ok, diagnostics}
  end

  def postcompile(status, _opts), do: status

  def reduce({{caller, callee}}, graph) do
    Graph.add_edge(graph, caller, callee)
  end

  def analyze(graph, opts \\ []) do
    dotfile_path = "./function_graph.dot"
    pdf_path = "./function_graph.pdf"
    Graph.to_dot(graph, dotfile_path)

    if Keyword.get(opts, :gen_pdf, false) do
      System.cmd("dot", ["-Tpdf", dotfile_path, "-o", pdf_path])
    end

    :ok
  end

  def assert_true(true), do: :ok
  def assert_true(false), do: raise("Wrong answer!")

  def assert_false(false), do: :ok
  def assert_false(true), do: raise("Wrong answer!")
end
