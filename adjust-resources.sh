#!/bin/bash

# Adjust as needed
CPU_LIMIT=12
MEMORY_LIMIT=42g
MEMORY_SWAP_LIMIT=42g

CLUSTER_NAME=spanmetrics-test

echo "🔧 Updating resource limits for all nodes in cluster: $CLUSTER_NAME"

# Get all Docker containers for this Kind cluster
NODES=$(docker ps --filter "name=${CLUSTER_NAME}" --format "{{.Names}}")

for NODE in $NODES; do
  echo "➡️  Setting $CPU_LIMIT CPUs and $MEMORY_LIMIT memory for node: $NODE"
  docker update --cpus=$CPU_LIMIT --memory=$MEMORY_LIMIT --memory-swap=$MEMORY_SWAP_LIMIT $NODE
done

echo "✅ All nodes updated successfully."
