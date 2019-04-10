# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.Scheduler do
  @moduledoc """
  Scheduler.

  The workflow is as follows:

  * Add jobs to the store.
  * Every N ms, check for expired jobs and send them to the execution queue.
  """
  use GenServer

  @poll_interval :pleroma_job_queue
                 |> Application.get_env(:scheduler, [])
                 |> Keyword.get(:poll_interval, :timer.seconds(10))

  @store :pleroma_job_queue
         |> Application.get_env(:scheduler, [])
         |> Keyword.get(:store, PleromaJobQueue.Scheduler.Store.ETS)

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec init(any()) :: {:ok, :ets.tid()} | :ignore
  @impl true
  def init(_) do
    with true <- PleromaJobQueue.enabled?() and enabled?(),
         {:ok, state} = @store.init([]) do
      schedule_next(:poll)
      {:ok, state}
    else
      _ -> :ignore
    end
  end

  @impl true
  def handle_cast({:enqueue_at, timestamp, queue_name, mod, args, priority}, state) do
    job = %{
      queue_name: queue_name,
      mod: mod,
      args: args,
      priority: priority
    }

    @store.insert(state, timestamp, job)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_all}, _, state) do
    result = @store.all(state)
    {:reply, result, state}
  end

  def get_all do
    GenServer.call(__MODULE__, {:get_all})
  end

  @impl true
  def handle_info(:poll, state) do
    now = :os.system_time(:millisecond)
    @store.drain(state, now)
    schedule_next(:poll)
    {:noreply, state}
  end

  defp schedule_next(:poll) do
    Process.send_after(self(), :poll, @poll_interval)
  end

  def enabled? do
    :pleroma_job_queue
    |> Application.get_env(:scheduler, [])
    |> Keyword.get(:enabled, false)
  end
end
