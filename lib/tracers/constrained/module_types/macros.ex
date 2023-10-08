defmodule Tracers.Constrained.ModuleTypes.Macros do
  @moduledoc false

  defmacro deftype(type, camelized_type) do
    using_ast =
      quote do
        Tracers.Constrained.ModuleTypes.unquote(:"_define_type_#{inspect(type)}!")
      end

    module_name_ast = {:__aliases__, [alias: false], [:"#{camelized_type}"]}

    module_ast =
      quote do
        defmodule unquote(module_name_ast) do
          defmacro __using__(_) do
            unquote(using_ast)
          end

          def type(), do: unquote(type)
        end
      end

    functions_ast =
      quote do
        def unquote(:"_define_type_#{inspect(type)}!")(), do: nil
        def unquote(type)(), do: unquote(type)

        def unquote(:"#{type}?")(unquote(type)), do: true
        def unquote(:"#{type}?")(_), do: false
      end

    [module_ast, functions_ast]
  end

  defmacro deftypes(types) do
    stuff =
      for type <- types do
        camelized_type =
          type
          |> Atom.to_string()
          |> Macro.camelize()

        ast =
          quote do
            unquote(__MODULE__).deftype(unquote(type), unquote(camelized_type))
          end

        {camelized_type, ast}
      end

    {camelized_types, asts} =
      Enum.reduce(stuff, {[], []}, fn {camelized_type, ast}, {camelized_types, ast_acc} ->
        {[camelized_type | camelized_types], [ast | ast_acc]}
      end)

    camelized_types =
      camelized_types
      |> Enum.reverse(camelized_types)
      |> Enum.map(fn camelized_type ->
        Macro.expand(
          {:__aliases__, [alias: false],
           [:Tracers, :Constrained, :ModuleTypes, :"#{camelized_type}"]},
          __CALLER__
        )
      end)

    asts = Enum.reverse(asts)

    guard_ast =
      quote do
        defguard is_module_type(type) when type in unquote(types)

        defguard is_legal_module(module)
                 when module in unquote(camelized_types)
      end

    [asts, guard_ast]
  end
end
