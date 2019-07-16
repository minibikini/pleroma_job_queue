# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.SchedulerTest do
  use ExUnit.Case

  defmodule(TestWorker, do: def(perform(:test_job, _, _), do: :ok))

  alias PleromaJobQueue.Scheduler

  @queue_name :testing

  test "enqueue_at" do
    time1 = :os.system_time(:millisecond) - :timer.seconds(4)
    time2 = :os.system_time(:millisecond) + :timer.seconds(4)
    time3 = :os.system_time(:millisecond) + :timer.seconds(14)

    PleromaJobQueue.enqueue_at(time1, @queue_name, TestWorker, [:test_job, :foo, :bar], 1)
    PleromaJobQueue.enqueue_at(time2, @queue_name, TestWorker, [:test_job, :foo, :bar], 2)
    PleromaJobQueue.enqueue_at(time3, @queue_name, TestWorker, [:test_job, :foo, :bar], 3)
    PleromaJobQueue.enqueue_at(time3, @queue_name, TestWorker, [:test_job, :bar, :foo], 3)

    pid = Process.whereis(Scheduler)
    Process.send(pid, :poll, [])

    expected1 =
      {time1,
       %{
         args: [:test_job, :foo, :bar],
         mod: TestWorker,
         priority: 1,
         queue_name: :testing
       }}

    expected2 =
      {time2,
       %{
         args: [:test_job, :foo, :bar],
         mod: TestWorker,
         priority: 2,
         queue_name: :testing
       }}

    expected3 =
      {time3,
       %{
         args: [:test_job, :foo, :bar],
         mod: TestWorker,
         priority: 3,
         queue_name: :testing
       }}

    expected4 =
      {time3,
       %{
         args: [:test_job, :bar, :foo],
         mod: TestWorker,
         priority: 3,
         queue_name: :testing
       }}

    result = Scheduler.get_all()
    refute expected1 in result
    assert expected2 in result
    assert expected3 in result
    assert expected4 in result
  end
end
