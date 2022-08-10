defmodule Tracers.ConstrainedCompiler do
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
  end

  def trace({:on_module, bytecode, _}, env) do
  end

  def trace(_, _) do
    :ok
  end
end
