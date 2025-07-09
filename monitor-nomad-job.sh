#!/bin/bash
# Monitor a Nomad job and capture Docker logs

JOB_ID="$1"
if [ -z "$JOB_ID" ]; then
  echo "Usage: $0 <job-id>"
  exit 1
fi

echo "Monitoring Nomad job: $JOB_ID"

# Function to get allocation ID
get_alloc_id() {
  curl -s "http://localhost:4646/v1/job/$JOB_ID/allocations" | jq -r '.[0].ID // empty'
}

# Function to get container ID from allocation
get_container_id() {
  local alloc_id="$1"
  docker ps -a --filter "label=com.hashicorp.nomad.alloc_id=$alloc_id" --format "{{.ID}}" | head -1
}

# Wait for allocation
echo "Waiting for allocation..."
while true; do
  ALLOC_ID=$(get_alloc_id)
  if [ -n "$ALLOC_ID" ]; then
    echo "Found allocation: $ALLOC_ID"
    break
  fi
  sleep 1
done

# Monitor container logs
echo "Monitoring container logs..."
LAST_CONTAINER=""
while true; do
  # Get current container ID
  CONTAINER_ID=$(get_container_id "$ALLOC_ID")
  
  if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "$LAST_CONTAINER" ]; then
    echo "=== New container detected: $CONTAINER_ID ==="
    LAST_CONTAINER="$CONTAINER_ID"
    
    # Follow logs until container stops
    docker logs -f "$CONTAINER_ID" 2>&1 || true
    echo "=== Container $CONTAINER_ID stopped ==="
  fi
  
  # Check job status
  JOB_STATUS=$(curl -s "http://localhost:4646/v1/job/$JOB_ID" | jq -r '.Status // empty')
  if [ "$JOB_STATUS" = "dead" ]; then
    echo "Job completed with status: $JOB_STATUS"
    break
  fi
  
  sleep 1
done