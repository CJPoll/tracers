defmodule Tracers.Constrained.Tracer do
  import Tracers.Constrained.ModuleTypes

  alias Tracers.Constrained.Server

  def trace(
        {:remote_macro, _meta, mod, :__using__, 1},
        env,
        server_name
      )
      when is_legal_module(mod) do
    Server.module_type_declared(server_name, mod.type(), env)
    :ok
  end

  def trace({:remote_function, _meta, module, function, arity}, env, server_name) do
    Server.function_dependency(server_name, {module, function, arity}, env)
  end

  def trace(_event, _env, _server_name) do
    :ok
  end
end
