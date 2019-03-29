defmodule PleromaJobQueue.MixProject do
  use Mix.Project

  def project do
    [
      app: :pleroma_job_queue,
      name: "Pleroma Job Queue",
      description: "A lightweight job queue",
      version: "0.2.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # Docs
      name: "PleromaJobQueue",
      source_url: "https://git.pleroma.social/pleroma/pleroma_job_queue",
      homepage_url: "https://git.pleroma.social/pleroma/pleroma_job_queue",
      docs: [
        main: "PleromaJobQueue",
        source_url_pattern:
          "https://git.pleroma.social/pleroma/pleroma_job_queue/blob/master/%{path}#L%{line}"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PleromaJobQueue.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.5", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["AGPLv3"],
      links: %{"GitLab" => "https://git.pleroma.social/pleroma/pleroma_job_queue"}
    ]
  end
end
