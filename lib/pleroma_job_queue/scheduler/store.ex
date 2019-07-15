# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.Scheduler.Store do
  @moduledoc """
  Defines an interface for the store
  """

  @doc """
  Initialize the store.
  """
  @callback init(options :: list) :: {:ok, store :: any()} | {:error, error :: any()}

  @doc """
  Insert a scheduled job.

  * `store` - a representation of the store
  * `timestamp` - a unix timestamp when the job should be enqueued to the execution queue.
  * `job` - a map that represents the job
  """
  @callback insert(store :: any(), timestamp :: pos_integer, job :: map) :: :ok | {:error, any()}

  @doc """
  Delete the jobs that are expired and send them to the execution queue.

  * `store` - a representation of the store.
  * `timestamp` - a unix timestamp past which the jobs should be considered expired.
  """
  @callback drain(store :: any(), timestamp :: pos_integer) :: any()

  @doc """
  Retrieve all the jobs currently present in the store.
  """
  @callback all(store :: any()) :: list
end
