defmodule Tracers.Constrained.ModuleTypes do
  import Tracers.Constrained.ModuleTypes.Macros

  deftypes([
    :pure,
    :changeset,
    :query_builder,
    :activity,
    :workflow,
    :framework
  ])
end
