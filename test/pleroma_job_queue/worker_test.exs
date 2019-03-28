# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.WorkerTest do
  use ExUnit.Case

  defmodule(TestWorker, do: def(perform(:test_job, _, _), do: :ok))

  alias PleromaJobQueue.State
  alias PleromaJobQueue.Worker

  @queue_name :testing

  setup do
    state = %State{
      queues: Enum.into([Worker.create_queue(@queue_name)], %{}),
      refs: %{}
    }

    [state: state]
  end

  test "creates queue" do
    queue = Worker.create_queue(:foobar)

    assert {:foobar, set} = queue
    assert :set == set |> elem(0) |> elem(0)
  end

  test "enqueues an element according to priority" do
    queue = [%{item: 1, priority: 2}]

    new_queue = Worker.enqueue_sorted(queue, 2, 1)
    assert new_queue == [%{item: 2, priority: 1}, %{item: 1, priority: 2}]

    new_queue = Worker.enqueue_sorted(queue, 2, 3)
    assert new_queue == [%{item: 1, priority: 2}, %{item: 2, priority: 3}]
  end

  test "pop first item" do
    queue = [%{item: 2, priority: 1}, %{item: 1, priority: 2}]

    assert {2, [%{item: 1, priority: 2}]} = Worker.queue_pop(queue)
  end

  test "enqueue a job", %{state: state} do
    assert {:noreply, new_state} =
             Worker.handle_cast(
               {:enqueue, @queue_name, TestWorker, [:test_job, :foo, :bar], 3},
               state
             )

    assert %{queues: %{testing: {running_jobs, []}}, refs: _} = new_state
    assert :sets.size(running_jobs) == 1
    assert [ref] = :sets.to_list(running_jobs)
    assert %{refs: %{^ref => @queue_name}} = new_state
  end

  test "max jobs setting", %{state: state} do
    max_jobs = PleromaJobQueue.max_jobs(@queue_name)

    {:noreply, state} =
      Enum.reduce(1..(max_jobs + 1), {:noreply, state}, fn _, {:noreply, state} ->
        Worker.handle_cast(
          {:enqueue, @queue_name, TestWorker, [:test_job, :foo, :bar], 3},
          state
        )
      end)

    assert %{
             queues: %{
               testing:
                 {running_jobs, [%{item: {TestWorker, [:test_job, :foo, :bar]}, priority: 3}]}
             }
           } = state

    assert :sets.size(running_jobs) == max_jobs
  end

  test "remove job after it finished", %{state: state} do
    {:noreply, new_state} =
      Worker.handle_cast(
        {:enqueue, @queue_name, TestWorker, [:test_job, :foo, :bar], 3},
        state
      )

    %{queues: %{testing: {running_jobs, []}}} = new_state
    [ref] = :sets.to_list(running_jobs)

    assert {:noreply, %{queues: %{testing: {running_jobs, []}}, refs: %{}}} =
             Worker.handle_info({:DOWN, ref, :process, nil, nil}, new_state)

    assert :sets.size(running_jobs) == 0
  end
end
