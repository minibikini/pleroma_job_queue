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
  def init(state) do
    queues =
      :pleroma_job_queue
      |> Application.get_all_env()
      |> Enum.map(fn {name, _} -> create_queue(name) end)
      |> Enum.into(%{})
      |> Map.merge(state.queues)

    {:ok, Map.put(state, :queues, queues)}
  end

  @impl true
  def handle_cast({:enqueue, queue_name, mod, args, priority}, state) do
    {running_jobs, queue} = state.queues[queue_name]

    queue = enqueue_sorted(queue, {mod, args}, priority)

    state =
      state
      |> update_queue(queue_name, {running_jobs, queue})
      |> maybe_start_job(queue_name, running_jobs, queue)

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
  def maybe_start_job(state, _queue_name, _running_jobs, []), do: state

  def maybe_start_job(state, queue_name, running_jobs, queue) do
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

  @spec create_queue(atom()) :: {atom(), {State.running_jobs(), State.queue()}}
  def create_queue(queue_name) do
    {queue_name, {:sets.new(), []}}
  end

  @spec enqueue_sorted(State.queue(), State.job(), non_neg_integer()) :: State.queue()
  def enqueue_sorted(queue, element, priority) do
    Enum.sort_by([%{item: element, priority: priority} | queue], & &1.priority)
  end

  @spec queue_pop(State.queue()) :: {State.job(), State.queue()}
  def queue_pop([%{item: element} | queue]) do
    {element, queue}
  end

  defp add_ref(state, queue_name, ref) do
    refs = Map.put(state.refs, ref, queue_name)
    %State{state | refs: refs}
  end

  defp remove_ref(state, ref) do
    refs = Map.delete(state.refs, ref)
    %State{state | refs: refs}
  end

  defp update_queue(state, queue_name, data) do
    queues = Map.put(state.queues, queue_name, data)
    %State{state | queues: queues}
  end
end
