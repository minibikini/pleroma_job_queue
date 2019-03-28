# 🗳 Pleroma Job Queue

> A lightweight job queue.

## Installation

Add `pleroma_job_queue` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pleroma_job_queue, "~> 0.1.0"}
  ]
end
```

## Configuration

You need list your queues with max concurrent jobs, like this:

```elixir
config :pleroma_job_queue,
  my_queue: 100,
  another_queue: 50
```


## Usage

[See documentation](http://hexdocs.pm/pleroma_job_queue)

## Contibuting

TBD

## License

TBD