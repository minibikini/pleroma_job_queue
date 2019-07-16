# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.WorkerTest do
  use ExUnit.Case

  import Mock

  defmodule(TestWorker, do: def(perform(:test_job, _, _), do: :ok))

  alias PleromaJobQueue.State
  alias PleromaJobQueue.Worker

  @queue_name :testing

  setup do
    state = %State{
      queues: Enum.into([Worker.create_queue()], %{}),
      refs: %{}
    }

    [state: state]
  end

  test "create_queue/1" do
    {running_jobs, queue} = Worker.create_queue()

    assert queue == []
    assert :sets.is_set(running_jobs)
    assert :sets.is_empty(running_jobs)
    assert PleromaJobQueue.max_jobs(:foobar) == 1
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

  defmodule ScheduledWorker do
    def perform(pid) do
      send(pid, :executing)
    end
  end

  describe "Scheduling" do
    setup do
      Application.stop(:pleroma_job_queue)

      schedule = [
        test_queue: %{
          cron_expr: "* * * * *",
          module: __MODULE__.ScheduledWorker,
          args: [self()]
        }
      ]

      Application.put_env(:pleroma_job_queue, :schedule, schedule)
    end

    test "Scheduled tasks are executed repeatedly" do
      get_next_run_date_mock = [
        get_next_run_date: fn _cron_expr ->
          {:ok, NaiveDateTime.add(NaiveDateTime.utc_now(), 1, :second)}
        end
      ]

      with_mock Crontab.Scheduler, get_next_run_date_mock do
        Application.start(:pleroma_job_queue)

        Enum.each(1..3, fn _i ->
          assert_receive :executing, 1_500
        end)
      end
    end
  end
end
