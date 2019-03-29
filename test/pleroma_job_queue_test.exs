# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueueTest do
  use ExUnit.Case

  defmodule Worker do
    defp pid, do: Application.get_env(:pleroma_job_queue, :test_pid)

    def perform, do: send(pid(), {:test, :no_args})
    def perform(:skip), do: nil
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

  test "max_jobs/1" do
    assert Application.get_env(:pleroma_job_queue, @queue_name, 1) ==
             PleromaJobQueue.max_jobs(@queue_name)
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

  defp set_pid, do: Application.put_env(:pleroma_job_queue, :test_pid, self())
end
