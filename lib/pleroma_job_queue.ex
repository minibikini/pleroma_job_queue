# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue do
  @moduledoc """
  A lightweight job queue

  ## Installation

  Add `pleroma_job_queue` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:pleroma_job_queue, "~> 0.1.0"}
    ]
  end
  ```

  ## Configuration

  You need to list your queues with max concurrent jobs like this:

  ```elixir
  config :pleroma_job_queue,
    my_queue: 100,
    another_queue: 50
  ```

  """

  @doc """
  Enqueues a job.

  Returns `:ok`.

  ## Arguments

  - `queue_name` - a queue name(must be specified in the config).
  - `mod` - a worker module (must have `perform` function).
  - `args` - a list of arguments for the `perform` function of the worker module.
  - `priority` - a job priority (`1` by default). The higher number has a lower priority.

  ## Examples

  Enqueue `MyWorker.perform/0` with `priority=1`:

      iex> PleromaJobQueue.enqueue(:example_queue, MyWorker)
      :ok

  Enqueue `MyWorker.perform(:job_name)` with `priority=5`:

      iex> PleromaJobQueue.enqueue(:example_queue, MyWorker, [:job_name], 5)
      :ok

  Enqueue `MyWorker.perform(:another_job, data)` with `priority=1`:

      iex> data = "foobar"
      iex> PleromaJobQueue.enqueue(:example_queue, MyWorker, [:another_job, data])
      :ok

  Enqueue `MyWorker.perform(:foobar_job, :foo, :bar, 42)` with `priority=1`:

      iex> PleromaJobQueue.enqueue(:example_queue, MyWorker, [:foobar_job, :foo, :bar, 42])
      :ok

  """

  @spec enqueue(atom(), module(), [any()], non_neg_integer()) :: :ok
  def enqueue(queue_name, mod, args \\ [], priority \\ 1) do
    GenServer.cast(PleromaJobQueue.Worker, {:enqueue, queue_name, mod, args, priority})
  end

  @doc """
  Returns a maximum concurrent jobs for a given queue name.
  """

  @spec max_jobs(atom()) :: non_neg_integer() | nil
  def max_jobs(queue_name) do
    Application.get_env(:pleroma_job_queue, queue_name)
  end
end
