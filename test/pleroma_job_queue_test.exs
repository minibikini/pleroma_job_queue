# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueueTest do
  use ExUnit.Case
  alias PleromaJobQueue.Scheduler

  import Mock

  defmodule Worker do
    defp pid, do: Application.get_env(:pleroma_job_queue, :test_pid)

    def perform, do: send(pid(), {:test, :no_args})
    def perform(:skip), do: nil
    def perform(:sync), do: :sync
    def perform(:test_job), do: send(pid(), :test_job)
    def perform(:test_job, a, b), do: send(pid(), {:test_job, {a, b}})
    def perform(:priority, priority), do: send(pid(), {:priority, priority})
  end

  @queue_name :testing

  test "enqueue/4" do
    set_pid()

    assert :ok == PleromaJobQueue.enqueue(@queue_name, Worker)
    assert_receive {:test, :no_args}

    assert :ok == PleromaJobQueue.enqueue(@queue_name, Worker, [:test_job])
    assert_receive :test_job

    assert :ok == PleromaJobQueue.enqueue(@queue_name, Worker, [:test_job, :foo, :bar])
    assert_receive {:test_job, {:foo, :bar}}
  end

  test "enqueue_at/5" do
    set_pid()

    future = :os.system_time(:millisecond) + :timer.seconds(4)
    past = :os.system_time(:millisecond) - :timer.seconds(4)
    :ok = PleromaJobQueue.enqueue_at(future, @queue_name, Worker, [:test_job, :future, :bar])
    :ok = PleromaJobQueue.enqueue_at(past, @queue_name, Worker, [:test_job, :past, :bar])
    pid = Process.whereis(Scheduler)
    Process.send(pid, :poll, [])

    refute_receive {:test_job, {:future, :bar}}
    assert_receive {:test_job, {:past, :bar}}
  end

  test "enqueue_in/5" do
    set_pid()

    offset1 = :timer.seconds(4)
    offset2 = :timer.seconds(14)
    :ok = PleromaJobQueue.enqueue_in(offset1, @queue_name, Worker, [:test_job, :foo, :bar1])
    :ok = PleromaJobQueue.enqueue_in(offset2, @queue_name, Worker, [:test_job, :foo, :bar2])
    pid = Process.whereis(Scheduler)
    Process.send(pid, :poll, [])

    result = Scheduler.get_all() |> Enum.map(&elem(&1, 1).args)
    assert [:test_job, :foo, :bar1] in result
    assert [:test_job, :foo, :bar2] in result
  end

  test "max_jobs/1" do
    assert Application.get_env(:pleroma_job_queue, @queue_name, 1) ==
             PleromaJobQueue.max_jobs(@queue_name)
  end

  test "disable" do
    Application.put_env(:pleroma_job_queue, :disabled, true)
    assert :sync == PleromaJobQueue.enqueue(@queue_name, Worker, [:sync])
    Application.put_env(:pleroma_job_queue, :disabled, false)
  end

  test "priority" do
    set_pid()

    PleromaJobQueue.enqueue(@queue_name, Worker, [:skip], 11)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 12], 12)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 13], 13)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 20], 20)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 14], 14)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 15], 15)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 16], 16)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 17], 17)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 18], 18)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 19], 19)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 19], 19)
    PleromaJobQueue.enqueue(@queue_name, Worker, [:priority, 1], 1)

    assert_receive {:priority, priority}
    assert priority == 1
  end

  test "schedule" do
    set_pid()

    get_next_run_date_mock = [
      get_next_run_date: fn _cron_expr ->
        NaiveDateTime.add(NaiveDateTime.utc_now(), 1, :second)
      end
    ]

    with_mock Crontab.Scheduler, get_next_run_date_mock do
      PleromaJobQueue.schedule("* * * * *", @queue_name, Worker)
      assert_receive {:test, :no_args}, 1_500
    end
  end

  defp set_pid, do: Application.put_env(:pleroma_job_queue, :test_pid, self())
end
