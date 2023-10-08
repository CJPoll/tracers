defmodule Example do
  use Tracers.Constrained.ModuleTypes.Pure

  alias Example.Repo

  def hello do
    Repo.one("fake_table")
  end
end
