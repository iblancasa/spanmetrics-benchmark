# OpenTelemetry Collector Spanmetrics Benchmark

This project benchmarks different OpenTelemetry Collector configurations related to **spanmetrics**, focusing on their **CPU and memory usage** under simulated load.

The results help evaluate the performance cost of enabling span-level metrics collection.
---

## 🧪 Benchmark Scenarios

The benchmarks compare the following configurations:

1. **Just Spans**  
   Basic OTLP span ingestion, no spanmetrics enabled.

2. **Spanmetrics Enabled**  
   OTEL collector with `spanmetrics` processor enabled.

3. **Custom Preset**  
   OTEL collector with full preset: spanmetrics, DB metrics, error tracking, and extra dimensions (via `values.yaml`).

---

## 📁 Project Structure

| File / Folder                 | Description |
|------------------------------|-------------|
| `Makefile`                   | Helper commands to deploy collector, telemetrygen, and cluster |
| `values.yaml`                | Custom configuration for spanmetrics with extra features |
| `telemetrygen.yaml`          | Job spec to simulate services sending OTLP traces |
| `benchmark.sh`               | Main automation script to run and capture benchmarks |
| `results/`                   | Folder where CPU/memory usage and logs are saved |

---

## ▶️ How to Run the Benchmark

1. Export the environment variable `MY_CX_KEY` with the API Key from Coralogix.
3. Run `./benchmark.sh`


```sh
# Default (100 services)
./benchmark.sh

# Custom (1000 services)
./benchmark.sh 1000

# Quick test (10 services)
./benchmark.sh 10
```