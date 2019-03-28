# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueueTest do
  use ExUnit.Case

  defmodule Worker do
    defp pid, do: Application.get_env(:test, :pid)

    def perform, do: send(pid(), {:test, :no_args})
    def perform(:skip), do: nil
    def perform(:test_job), do: send(pid(), {:test, :test_job})
    def perform(:test_job, a, b), do: send(pid(), {:test, {a, b}})
    def perform(:priority, priority), do: send(pid(), {:priority, priority})
  end

  @queue_name :testing

  test "enqueue/4" do
    set_pid()

    assert :ok == PleromaJobQueue.enqueue(@queue_name, Worker)
    assert :no_args == receive_result(:test)

    assert :ok == PleromaJobQueue.enqueue(@queue_name, Worker, [:test_job])
    assert :test_job == receive_result(:test)

    assert :ok == PleromaJobQueue.enqueue(@queue_name, Worker, [:test_job, :foo, :bar])
    assert {:foo, :bar} == receive_result(:test)
  end

  test "max_jobs/1" do
    assert Application.get_env(:pleroma_job_queue, @queue_name, 0) ==
             PleromaJobQueue.max_jobs(@queue_name)
  end

  test "priority" do
    set_pid()

    PleromaJobQueue.enqueue(@queue_name, Worker, [:skip], 10)
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

    assert 1 == receive_result(:priority)
  end

  test "README install version check" do
    app = Keyword.get(Mix.Project.config(), :app)
    app_version = app |> Application.spec(:vsn) |> to_string()

    readme = File.read!("README.md")
    [_, readme_versions] = Regex.run(~r/{:#{app}, "(.+)"}/, readme)

    assert Version.match?(
             app_version,
             readme_versions
           ),
           """
           Install version constraint in README.md does not match to current app version.
           Current App Version: #{app_version}
           Readme Install Versions: #{readme_versions}
           """
  end

  test "PleromaJobQueue install version check" do
    app = Keyword.get(Mix.Project.config(), :app)
    app_version = app |> Application.spec(:vsn) |> to_string()

    readme = File.read!("lib/pleroma_job_queue.ex")
    [_, readme_versions] = Regex.run(~r/{:#{app}, "(.+)"}/, readme)

    assert Version.match?(
             app_version,
             readme_versions
           ),
           """
           Install version constraint in PleromaJobQueue.ex does not match to current app version.
           Current App Version: #{app_version}
           PleromaJobQueue Install Versions: #{readme_versions}
           """
  end

  defp receive_result(name) do
    receive do
      {^name, value} -> value
    end
  end

  defp set_pid, do: Application.put_env(:test, :pid, self())
end
