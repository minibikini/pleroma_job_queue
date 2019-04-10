# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.Scheduler.Store.ETS do
  @moduledoc """
  Implements a store using ETS.
  """

  alias PleromaJobQueue.Scheduler.Store
  @behaviour Store

  @impl true
  def init(_) do
    index_table = :ets.new(Module.concat([__MODULE__, IndexTable]), [:ordered_set])
    entry_table = :ets.new(Module.concat([__MODULE__, EntryTable]), [:duplicate_bag])
    {:ok, {index_table, entry_table}}
  end

  @impl true
  def insert({index_table, entry_table}, timestamp, job) do
    :ets.insert(index_table, {timestamp, :const})
    :ets.insert(entry_table, {timestamp, job})
    :ok
  end

  @impl true
  def drain({index_table, entry_table} = state, now) do
    first = :ets.first(index_table)

    cond do
      first == :"$end_of_table" ->
        :noop

      first <= now ->
        :ets.delete(index_table, first)

        entry_table
        |> :ets.take(first)
        |> Enum.each(fn {_, job} ->
          PleromaJobQueue.enqueue(job.queue_name, job.mod, job.args, job.priority)
        end)

        drain(state, now)

      true ->
        :noop
    end
  end

  @impl true
  def all({_index_table, entry_table}) do
    :ets.tab2list(entry_table)
  end
end
