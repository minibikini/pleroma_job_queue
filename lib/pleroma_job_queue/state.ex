# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
