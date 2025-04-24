#!/bin/bash

# colima start --vm-type vz --network-address --cpu 12 --memory 44

set -euo pipefail

if [ -z "$MY_CX_KEY" ]; then
  echo "❌ MY_CX_KEY is not set"
  exit 1
fi


# === Signal Handling ===
cleanup() {
    echo "🛑 Cleaning up..."
    # Kill the monitor process if it exists
    if [ -n "$MONITOR_PID" ]; then
        kill "$MONITOR_PID" 2>/dev/null || true
        wait "$MONITOR_PID" 2>/dev/null || true
    fi
    # Clean up any remaining telemetrygen jobs
    kubectl delete jobs -l app=telemetrygen --all-namespaces 2>/dev/null || true
    rm -f telemetrygen-temp.yaml
    exit 1
}

# Set up trap for SIGINT (Ctrl+C)
trap cleanup SIGINT

# === Input Parameters ===
NUM_SERVICES=${1:-100}

# === Validate Service Count ===
if ! [[ "$NUM_SERVICES" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid number of services: $NUM_SERVICES"
  echo "Usage: ./benchmark.sh [num_services]"
  exit 1
fi

mkdir -p results

echo "🔧 Running benchmark with:"
echo "   ➤ Services:  $NUM_SERVICES"

make start-cluster


CONFIGS=("just-spans" "spanmetrics" "preset-spanmetrics")

for config in "${CONFIGS[@]}"; do
  echo "=== 🚀 Running config: $config ==="
  
  kubectl create secret generic coralogix-keys --from-literal=PRIVATE_KEY="$MY_CX_KEY"

  case $config in
    just-spans)
      make install-collector
      ;;
    spanmetrics)
      make install-collector-with-spanmetrics
      ;;
    preset-spanmetrics)
      make install-collector-with-preset-spanmetrics
      ;;
  esac

  sleep 20

  # === Background Monitor for Summed Resource Usage ===
  MAX_TOTAL_CPU=0
  MAX_TOTAL_MEM=0

  monitor_usage() {
    while true; do
      TOTAL_CPU=0
      TOTAL_MEM=0
      echo ""

      # Get top output across all namespaces
      while IFS= read -r line; do
        ns=$(awk '{print $1}' <<< "$line")
        pod=$(awk '{print $2}' <<< "$line")
        cpu=$(awk '{print $3}' <<< "$line")
        mem=$(awk '{print $4}' <<< "$line")

        # Get individual labels
        name_label=$(kubectl get pod "$pod" -n "$ns" -o jsonpath="{.metadata.labels['app\.kubernetes\.io/name']}" 2>/dev/null)
        instance_label=$(kubectl get pod "$pod" -n "$ns" -o jsonpath="{.metadata.labels['app\.kubernetes\.io/instance']}" 2>/dev/null)

        if [[ "$name_label" == "opentelemetry-agent" && "$instance_label" == "otel-coralogix-integration" ]]; then
          cpu_val=${cpu%m}
          mem_val=${mem%Mi}

          [[ "$cpu_val" =~ ^[0-9]+$ ]] && (( TOTAL_CPU += cpu_val ))
          [[ "$mem_val" =~ ^[0-9]+$ ]] && (( TOTAL_MEM += mem_val ))
        fi
        
      done <<< "$(kubectl top pods -A --no-headers 2>/dev/null || true)"

      (( TOTAL_CPU > MAX_TOTAL_CPU )) && MAX_TOTAL_CPU=$TOTAL_CPU
      (( TOTAL_MEM > MAX_TOTAL_MEM )) && MAX_TOTAL_MEM=$TOTAL_MEM

      echo "🔍 Current max: CPU=${MAX_TOTAL_CPU}m, MEM=${MAX_TOTAL_MEM}Mi" >> results/$config-$NUM_SERVICES.txt
      sleep 2
    done
  }

  monitor_usage &
  MONITOR_PID=$!

  # Loop through services one by one
  for ((i=0; i<NUM_SERVICES; i++)); do    
    # Create temporary telemetrygen YAML for this service
    export SERVICE_NAME="service-$i"
    envsubst < telemetrygen.yaml > telemetrygen-temp.yaml
    
    # Apply the telemetrygen job
    kubectl apply -f telemetrygen-temp.yaml
  done

  # Wait for all telemetrygen jobs to complete
  echo "⏳ Waiting for all telemetrygen jobs to complete..."
  while true; do
    # Check if there are any pending pods
    if kubectl get pods -l app=telemetrygen -o jsonpath='{.items[*].status.phase}' | grep -q "Pending"; then
        echo "Still waiting for pending pods..."
        sleep 5
        continue
    fi
    
    # Check if all jobs are in a final state (Complete or Failed)
    if ! kubectl get jobs -l app=telemetrygen -o jsonpath='{.items[*].status.conditions[*].type}' | grep -q "Complete\|Failed"; then
        echo "Still waiting for jobs to complete..."
        sleep 5
        continue
    fi
    
    # If we get here, all pods are either running/completed/failed and all jobs are in final state
    break
  done

  # Kill background monitor and show max usage
  kill "$MONITOR_PID" 2>/dev/null || true
  wait "$MONITOR_PID" 2>/dev/null || true

  echo "finished at $(date)"
  echo "🔍 FINAL RESULTS: CPU=${MAX_TOTAL_CPU}m, MEM=${MAX_TOTAL_MEM}Mi"
done
