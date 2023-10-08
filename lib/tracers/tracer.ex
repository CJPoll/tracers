defmodule Tracers.Tracer do
  @callback trace(term, Macro.Env.t()) :: :ok
end
