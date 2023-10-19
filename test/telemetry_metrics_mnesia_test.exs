defmodule TelemetryMetricsMnesiaTest do
  alias Telemetry.Metrics.Counter
  alias Module.Types.Expr
  use ExUnit.Case, async: false

  alias :mnesia, as: Mnesia

  doctest TelemetryMetricsMnesia

  test "`counter` metrics report and fetch correctly" do
    counter = Telemetry.Metrics.counter([:test, :counter, :counter])

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: [counter])

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test, :counter], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:rest, :counter], %{val: i, total: n}, %{count: false})
    end

    assert %{"Counter" => n} =
             TelemetryMetricsMnesia.fetch([:test, :counter, :counter])

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "`last_value` metrics report and fetch correctly" do
    metrics = Telemetry.Metrics.last_value([:test, :last_value, :val])

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: [metrics])

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test, :last_value], %{val: i + n, total: n}, %{count: true})
      :telemetry.execute([:rest, :last_value], %{val: i + n, total: n}, %{count: false})
    end

    assert %{"LastValue" => out} =
             TelemetryMetricsMnesia.fetch([:test, :last_value, :val])

    assert out == 2 * n

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "`sum` metrics report and fetch correctly" do
    metrics = Telemetry.Metrics.sum([:test, :sum, :val])

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: [metrics])

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test, :sum], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:rest, :sum], %{val: i, total: n}, %{count: false})
    end

    assert %{"Sum" => out} = TelemetryMetricsMnesia.fetch([:test, :sum, :val])
    assert out == Enum.sum(1..n)

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "`distribution` metrics report and fetch correctly" do
    metrics = Telemetry.Metrics.distribution([:test, :distribution, :val])

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: [metrics])

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test, :distribution], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:rest, :distribution], %{val: i, total: n}, %{count: false})
    end

    assert %{
             "Distribution" => %{
               median: median,
               p75: p75,
               p90: p90,
               p95: p95,
               p99: p99
             }
           } = TelemetryMetricsMnesia.fetch([:test, :distribution, :val])

    assert median == (n + 1) / 2
    assert p75 == Float.ceil(n * 0.75)
    assert p90 == Float.ceil(n * 0.9)
    assert p95 == Float.ceil(n * 0.95)
    assert p99 == Float.ceil(n * 0.99)

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "`summary` metrics report and fetch correctly" do
    metrics = Telemetry.Metrics.summary([:test, :summary, :val])

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: [metrics])

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test, :summary], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:rest, :summary], %{val: i, total: n}, %{count: false})
    end

    assert %{
      "Summary" => %{
        mean: avg,
        variance: var,
        standard_deviation: sd,
        median: median,
        count: count
      }
    } = TelemetryMetricsMnesia.fetch([:test, :summary, :val])

    assert avg == Enum.sum(1..n) / n
    assert sd == 1..n |> Enum.to_list() |> Explorer.Series.from_list() |> Explorer.Series.standard_deviation()
    assert var == 1..n |> Enum.to_list() |> Explorer.Series.from_list() |> Explorer.Series.variance()
    assert count == n
    assert median == (n + 1) / 2

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "All metrics at once with different events report and fetch correctly" do
    metrics = [
      Telemetry.Metrics.counter([:test, :counter, :counter]),
      Telemetry.Metrics.sum([:test, :sum, :val]),
      Telemetry.Metrics.last_value([:test, :last_value, :val]),
      Telemetry.Metrics.distribution([:test, :distribution, :val]),
      Telemetry.Metrics.summary([:test, :summary, :val])
    ]

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: metrics)

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test, :counter], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:test, :sum], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:test, :last_value], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:test, :distribution], %{val: i, total: n}, %{count: true})
      :telemetry.execute([:test, :summary], %{val: i, total: n}, %{count: false})
    end

    assert %{"Counter" => ^n} =
             TelemetryMetricsMnesia.fetch([:test, :counter, :counter])

    assert %{"LastValue" => ^n} =
             TelemetryMetricsMnesia.fetch([:test, :last_value, :val])


    assert %{"Sum" => out} = TelemetryMetricsMnesia.fetch([:test, :sum, :val])
    assert out == Enum.sum(1..n)

    assert %{
             "Distribution" => %{
               median: _median,
               p75: _p7_5,
               p90: _p9_0,
               p95: _p9_5,
               p99: _p99
             }
           } = TelemetryMetricsMnesia.fetch([:test, :distribution, :val])


    assert %{
      "Summary" => %{
        mean: _avg,
        variance: _var,
        standard_deviation: _sd,
        median: _median,
        count: _count
      }
    } = TelemetryMetricsMnesia.fetch([:test, :summary, :val])

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "All metrics at once with the same event report and fetch correctly" do
    metrics = [
      Telemetry.Metrics.counter([:test, :counter]),
      Telemetry.Metrics.sum([:test, :val]),
      Telemetry.Metrics.last_value([:test, :val]),
      Telemetry.Metrics.distribution([:test, :val]),
      Telemetry.Metrics.summary([:test, :val])
    ]

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: metrics)

    n = :rand.uniform(10_000)

    for i <- 1..n do
      :telemetry.execute([:test], %{val: i, total: n}, %{count: true})
    end

    assert %{"Counter" => ^n} =
             TelemetryMetricsMnesia.fetch([:test, :counter])

    assert %{"LastValue" => ^n} =
             TelemetryMetricsMnesia.fetch([:test, :val])


    assert %{"Sum" => out} = TelemetryMetricsMnesia.fetch([:test, :val])
    assert out == Enum.sum(1..n)

    assert %{
             "Distribution" => %{
               median: _median,
               p75: _p7_5,
               p90: _p9_0,
               p95: _p9_5,
               p99: _p99
             }
           } = TelemetryMetricsMnesia.fetch([:test, :val])


    assert %{
      "Summary" => %{
        mean: _avg,
        variance: _var,
        standard_deviation: _sd,
        median: _median,
        count: _count
      }
    } = TelemetryMetricsMnesia.fetch([:test, :val])

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end

  test "`counter` metrics fetch correctly timings are ok" do
    counter = Telemetry.Metrics.counter([:test, :counter, :time, :counter])
    garbage = Telemetry.Metrics.counter([:test, :garbage, :time, :garbage])

    {:ok, pid} = TelemetryMetricsMnesia.start_link(metrics: [counter, garbage])

    n = 10_000

    times =
      for i <- 1..n do
        {t, :ok} = :timer.tc(fn ->
          :telemetry.execute([:test, :counter, :time], %{val: i, total: n}, %{count: true})
        end)
        :telemetry.execute([:test, :garbage, :time], %{val: i, total: n}, %{count: false})
        t
      end
    |> Explorer.Series.from_list()

    assert Explorer.Series.median(times) |> IO.inspect(label: "Insert time") <= 15
    assert Explorer.Series.quantile(times, 0.99) < 100

    {t, %{"Counter" => _}} =
      :timer.tc(fn ->
        TelemetryMetricsMnesia.fetch([:test, :counter, :time, :counter])
      end)

    assert t <= 5000

    GenServer.stop(pid)
    Mnesia.clear_table(:telemetry_events)
  end
end
