# PleromaJobQueue: A lightweight job queue
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule PleromaJobQueue.InstallVersionTest do
  use ExUnit.Case, async: true

  describe("install version check") do
    test "README.md" do
      assert_version("README.md")
    end

    test "lib/pleroma_job_queue.ex" do
      assert_version("lib/pleroma_job_queue.ex")
    end
  end

  defp assert_version(filename) do
    app = Keyword.get(Mix.Project.config(), :app)
    app_version = app |> Application.spec(:vsn) |> to_string()

    file = File.read!(filename)
    [_, file_versions] = Regex.run(~r/{:#{app}, "(.+)"}/, file)

    assert Version.match?(
             app_version,
             file_versions
           ),
           """
           Install version constraint in `#{filename}` does not match to current app version.
           Current App Version: #{app_version}
           `#{filename}` Install Versions: #{file_versions}
           """
  end
end
