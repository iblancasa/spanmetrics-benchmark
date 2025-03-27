#!/bin/bash

set -euo pipefail

# === Input Parameters ===
NUM_SERVICES=${1:-100}
DURATION_INPUT=${2:-30m}  # raw input: 30s, 1m, 5m, etc.

# === Validate Service Count ===
if ! [[ "$NUM_SERVICES" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid number of services: $NUM_SERVICES"
  echo "Usage: ./benchmark.sh [num_services] [duration]"
  exit 1
fi

# === Convert Duration Input to Seconds ===
duration_to_seconds() {
  local input=$1
  if [[ $input =~ ^([0-9]+)s$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ $input =~ ^([0-9]+)m$ ]]; then
    echo "$(( ${BASH_REMATCH[1]} * 60 ))"
  else
    echo "❌ Unsupported duration format: $input (use Ns or Nm)"
    exit 1
  fi
}

DURATION_SECONDS=$(duration_to_seconds "$DURATION_INPUT")
WAIT_TIMEOUT_SECONDS=$(( DURATION_SECONDS + 120 ))
WAIT_TIMEOUT="${WAIT_TIMEOUT_SECONDS}s"

export PARALLELISM=$NUM_SERVICES
export COMPLETIONS=$NUM_SERVICES
export DURATION=$DURATION_INPUT

echo "🔧 Running benchmark with:"
echo "   ➤ Services:  $NUM_SERVICES"
echo "   ➤ Duration:  $DURATION_INPUT"
echo "   ➤ Wait timeout: $WAIT_TIMEOUT"

CONFIGS=("just-spans" "spanmetrics" "preset-spanmetrics")

for config in "${CONFIGS[@]}"; do
  echo "=== 🚀 Running config: $config ==="

  kubectl delete -f telemetrygen.yaml || true
  echo "starting at $(date)"

  case $config in
    just-spans)
      echo "running"
      ##make install-collector
      ;;
    spanmetrics)
      make install-collector-with-spanmetrics
      ;;
    preset-spanmetrics)
      make install-collector-with-preset-spanmetrics
      ;;
  esac

  # Create telemetrygen job with injected values
  envsubst < telemetrygen.yaml > telemetrygen-temp.yaml
  kubectl apply -f telemetrygen-temp.yaml

  echo "⏳ Waiting for telemetrygen job to complete (timeout: $WAIT_TIMEOUT)..."
  kubectl wait --for=condition=complete job/telemetrygen-job --timeout="$WAIT_TIMEOUT" || echo "⚠️ Job may not have completed in time"
  kubectl delete -f telemetrygen.yaml || true
  echo "finished at $(date)"
done

rm -f telemetrygen-temp.yaml

echo "✅ Benchmarking completed for $NUM_SERVICES services, duration $DURATION_INPUT"
