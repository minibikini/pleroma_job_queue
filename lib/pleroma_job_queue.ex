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
      {:pleroma_job_queue, "~> 0.3.0"}
    ]
  end
  ```

  ## Configuration

  List your queues with max concurrent jobs like this:

  ```elixir
  config :pleroma_job_queue, :queues,
    my_queue: 100,
    another_queue: 50
  ```

  You can disable `pleroma_job_queue` if you need to run your jobs synchronously:

  ```elixir
  config :pleroma_job_queue, disabled: true
  ```

  Configure the scheduler like this:

  ```elixir
  config :pleroma_job_queue, :scheduler,
    enabled: true,
    poll_interval: :timer.seconds(10),
    store: PleromaJobQueue.Scheduler.Store.ETS
  ```

  * `enabled` - whether the scheduler is enabled (Default: `true`)
  * `poll_interval` - how often to check for scheduled jobs in milliseconds (Default: `10_000`)
  * `store` - a module that stores scheduled jobs. It should implement the `PleromaJobQueue.Scheduler.Store` behavior. The default is an in-memory store based on ETS tables: `PleromaJobQueue.Scheduler.Store.ETS`.

  The scheduler allows you to execute jobs at specific time in the future.
  By default it uses an in-memory ETS table which means the jobs won't be available after restart.
  """

  @doc """
  Enqueues a job.

  Returns `:ok`.

  ## Arguments

  * `queue_name` - a queue name(must be specified in the config).
  * `mod` - a worker module (must have `perform` function).
  * `args` - a list of arguments for the `perform` function of the worker module.
  * `priority` - a job priority (`1` by default). The higher number has a lower priority.

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

  @spec enqueue(atom(), module(), [any()], non_neg_integer()) :: any()
  def enqueue(queue_name, mod, args \\ [], priority \\ 1) do
    if enabled?() do
      GenServer.cast(PleromaJobQueue.Worker, {:enqueue, queue_name, mod, args, priority})
    else
      apply(mod, :perform, args)
    end
  end

  @doc """
  Schedule a repeating task that will be enqueued with given params according to
  the given cron expression.

  In case of invalid cron expression given, an error will be returned.

  ## Examples

  Enqueue `MyWorker.perform/0` to be repeated every minute:

      iex> PleromaJobQueue.schedule("* * * * *", :queue_name, MyWorker)
      :ok

  Enqueue `MyWorker.perform(:arg1, :arg2)` with priority 5 to be repeated every Sunday midnight:

      iex> PleromaJobQueue.schedule("0 0 * * 7", :queue_name, MyWorker, [:arg1, :arg2], 5)
      :ok

  Invalid cron expression:

      iex> PleromaJobQueue.schedule("9 9 9 9 9", :queue_name, MyWorker, [:arg1, :arg2], 5)
      {:error, "Can't parse 9 as day of week"}

  """
  @spec schedule(String.t(), atom(), module(), [any()], non_neg_integer()) ::
          :ok | {:error, String.t()}
  def schedule(schedule, queue, mod, args \\ [], priority \\ 1) do
    with {:ok, %Crontab.CronExpression{} = cron_expr} <-
           Crontab.CronExpression.Parser.parse(schedule) do
      send(PleromaJobQueue.Worker, {:schedule, cron_expr, queue, mod, args, priority})
      :ok
    end
  end

  @doc """
  Schedules a job to be enqueued at specific time in the future.

  ## Arguments

  * `timestamp` - a unix timestamp in milliseconds
  * `queue_name` - a queue name (must be specified in the config).
  * `mod` - a worker module (must have `perform` function).
  * `args` - a list of arguments for the `perform` function of the worker module.
  * `priority` - a job priority (`1` by default). The higher number has a lower priority.

  ## Examples

  Enqueue `MyWorker.perform/0` at specific time:

      iex> time = DateTime.to_unix(DateTime.utc_now(), :millisecond)
      iex> enqueue_at(time, :example_queue, MyWorker)
      :ok
  """
  @spec enqueue_at(pos_integer, atom(), module(), [any()], non_neg_integer()) :: any()
  def enqueue_at(timestamp, queue_name, mod, args \\ [], priority \\ 1) do
    if enabled?() do
      GenServer.cast(
        PleromaJobQueue.Scheduler,
        {:enqueue_at, timestamp, queue_name, mod, args, priority}
      )
    end
  end

  @doc """
  Schedules a job to be enqueued after the given offset in milliseconds.

  ## Arguments

  * `offset` - an offset from now in milliseconds
  * `queue_name` - a queue name (must be specified in the config).
  * `mod` - a worker module (must have `perform` function).
  * `args` - a list of arguments for the `perform` function of the worker module.
  * `priority` - a job priority (`1` by default). The higher number has a lower priority.

  ## Examples

  Enqueue `MyWorker.perform/0` after 10 seconds:

      iex> enqueue_in(:timer.seconds(10), :example_queue, MyWorker)
      :ok
  """
  @spec enqueue_in(non_neg_integer(), atom(), module(), [any()], non_neg_integer()) :: any()
  def enqueue_in(offset, queue_name, mod, args \\ [], priority \\ 1) do
    now = :os.system_time(:millisecond)
    enqueue_at(now + offset, queue_name, mod, args, priority)
  end

  @doc """
  Returns a maximum concurrent jobs for a given queue name.
  """

  @spec max_jobs(atom()) :: non_neg_integer()
  def max_jobs(queue_name) do
    :pleroma_job_queue
    |> Application.get_env(:queues, [])
    |> Keyword.get(queue_name, 1)
  end

  def enabled?(), do: not Application.get_env(:pleroma_job_queue, :disabled, false)
end
