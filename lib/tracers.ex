defmodule Tracers do
  @callback tracer(term, Macro.Env.t()) :: :ok

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end
