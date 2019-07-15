# 🗳 Pleroma Job Queue

[![pipeline status](https://git.pleroma.social/pleroma/pleroma_job_queue/badges/master/pipeline.svg)](https://git.pleroma.social/pleroma/pleroma_job_queue/commits/master)
[![coverage report](https://git.pleroma.social/pleroma/pleroma_job_queue/badges/master/coverage.svg)](https://git.pleroma.social/pleroma/pleroma_job_queue/commits/master)
[![Hex pm](https://img.shields.io/hexpm/v/pleroma_job_queue.svg?style=flat)](https://hex.pm/packages/pleroma_job_queue)

> A lightweight job queue

## Installation

Add `pleroma_job_queue` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pleroma_job_queue, "~> 0.2.0"}
  ]
end
```

## Configuration

List your queues with max concurrent jobs like this:

```elixir
config :pleroma_job_queue, :queues,
  my_queue: 100,
  another_queue: 50
```

Configure the scheduler like this:

```elixir
config :pleroma_job_queue, :scheduler,
  enabled: true,
  poll_interval: :timer.seconds(10),
  store: PleromaJobQueue.Scheduler.Store.ETS
```

* `enabled` - whether the scheduler is enabled (Default: `false`)
* `poll_interval` - how often to check for scheduled jobs in milliseconds (Default: `10_000`)
* `store` - a module that stores scheduled jobs. It should implement the `PleromaJobQueue.Scheduler.Store` behavior. The default is an in-memory store based on ETS tables: `PleromaJobQueue.Scheduler.Store.ETS`.

The scheduler allows you to execute jobs at specific time in the future.
By default it uses an in-memory ETS table which means the jobs won't be available after restart.

## Usage

[See documentation](http://hexdocs.pm/pleroma_job_queue)

## Copyright and License

Copyright © 2017-2019 [Pleroma Authors](https://pleroma.social/)

Pleroma Job Queue source code is licensed under the AGPLv3 License.
