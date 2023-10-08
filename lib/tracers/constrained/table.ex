defmodule Tracers.Constrained.Table do
  defstruct [:table]

  def from_name(table_name) when is_atom(table_name), do: %__MODULE__{table: table_name}

  def create(%__MODULE__{table: table_name} = table) when is_atom(table_name) do
    :ets.new(table_name, [:named_table, :public, :set])
    table
  end

  def insert(%__MODULE__{table: table_name} = table, data) when is_atom(table_name) do
    :ets.insert(table_name, data)
    table
  end

  def lookup(%__MODULE__{table: table_name}, key) when is_atom(table_name) do
    :ets.lookup(table_name, key)
  end

  def lookup_one(%__MODULE__{table: table_name}, key) when is_atom(table_name) do
    case :ets.lookup(table_name, key) do
      [] -> nil
      [one] -> one
      [_ | _] -> raise "Multiple records found in #{table_name} for key: #{key}"
    end
  end

  def match(%__MODULE__{table: table_name}, pattern) when is_atom(table_name) do
    :ets.match(table_name, pattern)
  end

  def reduce(%__MODULE__{table: table_name}, acc, reducer)
      when is_atom(table_name) and is_function(reducer, 2) do
    :ets.foldl(reducer, acc, table_name)
  end
end
