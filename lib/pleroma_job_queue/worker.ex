# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.Worker do
  @moduledoc """
  Queue Worker
  """
  use GenServer

  import PleromaJobQueue, only: [max_jobs: 1]
  alias PleromaJobQueue.State

  def start_link([]) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  @impl true
  @spec init(State.t()) :: {:ok, State.t()}
  def init(%State{queues: queues} = state) do
    queues =
      :pleroma_job_queue
      |> Application.get_env(:queues, [])
      |> Enum.map(fn {name, _} -> {name, create_queue()} end)
      |> Enum.into(%{})
      |> Map.merge(queues)

    :pleroma_job_queue
    |> Application.get_env(:schedule, [])
    |> Enum.each(fn {queue, %{cron_expr: cron_expr_unparsed, module: mod} = params} ->
      with %Crontab.CronExpression{} = cron_expr <-
             Crontab.CronExpression.Parser.parse(cron_expr_unparsed) do
        args = Map.get(params, :args, [])
        priority = Map.get(params, :priority, 1)
        send(self(), {:schedule, cron_expr, queue, mod, args, priority})
      end
    end)

    {:ok, %State{state | queues: queues}}
  end

  @impl true
  def handle_cast({:enqueue, queue_name, mod, args, priority}, %State{queues: queues} = state) do
    {running_jobs, queue} = Map.get(queues, queue_name, create_queue())

    queue = enqueue_sorted(queue, {mod, args}, priority)

    state =
      state
      |> update_queue(queue_name, {running_jobs, queue})
      |> maybe_start_job(queue_name, running_jobs, queue)

    {:noreply, state}
  end

  def handle_info(
        {:schedule, %Crontab.CronExpression{} = cron_expr, queue, mod, args, priority},
        state
      ) do
    next_run_date = Crontab.Scheduler.get_next_run_date(cron_expr)
    interval = NaiveDateTime.diff(next_run_date, NaiveDateTime.utc_now())

    Process.send_after(
      self(),
      {:enqueue_scheduled, queue, mod, args, priority, interval},
      interval
    )

    {:noreply, state}
  end

  def handle_info({:enqueue_scheduled, queue, mod, args, priority, interval}, state) do
    GenServer.cast(self(), {:enqueue, queue, mod, args, priority})

    Process.send_after(
      self(),
      {:enqueue_scheduled, queue, mod, args, priority, interval},
      interval
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    queue_name = state.refs[ref]

    {running_jobs, queue} = state.queues[queue_name]

    running_jobs = :sets.del_element(ref, running_jobs)

    state =
      state
      |> remove_ref(ref)
      |> update_queue(queue_name, {running_jobs, queue})
      |> maybe_start_job(queue_name, running_jobs, queue)

    {:noreply, state}
  end

  @spec maybe_start_job(State.t(), atom(), State.running_jobs(), State.queue()) :: State.t()
  def maybe_start_job(%State{} = state, _queue_name, _running_jobs, []), do: state

  def maybe_start_job(%State{} = state, queue_name, running_jobs, queue) do
    if :sets.size(running_jobs) < max_jobs(queue_name) do
      {{mod, args}, queue} = queue_pop(queue)
      {:ok, pid} = Task.start(fn -> apply(mod, :perform, args) end)
      mref = Process.monitor(pid)

      state
      |> add_ref(queue_name, mref)
      |> update_queue(queue_name, {:sets.add_element(mref, running_jobs), queue})
    else
      state
    end
  end

  @spec create_queue() :: {State.running_jobs(), State.queue()}
  def create_queue do
    {:sets.new(), []}
  end

  @spec enqueue_sorted(State.queue(), State.job(), non_neg_integer()) :: State.queue()
  def enqueue_sorted(queue, element, priority) do
    Enum.sort_by([%{item: element, priority: priority} | queue], & &1.priority)
  end

  @spec queue_pop(State.queue()) :: {State.job(), State.queue()}
  def queue_pop([%{item: element} | queue]) do
    {element, queue}
  end

  defp add_ref(%State{refs: refs} = state, queue_name, ref) do
    %State{state | refs: Map.put(refs, ref, queue_name)}
  end

  defp remove_ref(%State{refs: refs} = state, ref) do
    %State{state | refs: Map.delete(refs, ref)}
  end

  defp update_queue(%State{queues: queues} = state, queue_name, data) do
    %State{state | queues: Map.put(queues, queue_name, data)}
  end
end
