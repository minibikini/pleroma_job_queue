defmodule PleromaJobQueue.State do
  @moduledoc """
  A queue state
  """
  
  defstruct queues: %{}, refs: %{}

  @type t :: %__MODULE__{
          queues: %{optional(atom()) => {running_jobs(), queue()}},
          refs: %{optional(reference()) => atom()}
        }

  @type job :: {module(), [any()]}
  @type running_jobs :: :sets.set(reference())
  @type queue :: [
          %{
            item: job(),
            priority: non_neg_integer()
          }
        ]
end
