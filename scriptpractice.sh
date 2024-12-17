#!/bin/bash

# Memory threshold in percentage
MEMORY_THRESHOLD=20

# Interval to check processes (in seconds)
CHECK_INTERVAL=10

# Log file to record actions taken
LOG_FILE="/var/log/memory_monitor.log"

# Function to get top memory-consuming processes
get_top_memory_consumers() {
    # Print top processes sorted by memory usage (excluding header row)
    ps axo pid,comm,%mem --sort=-%mem | awk -v threshold="$MEMORY_THRESHOLD" 'NR>1 && $3 >= threshold {print $1, $2, $3}'
}

# Function to regulate process
regulate_process() {
    local pid=$1
    local process_name=$2
    local mem_usage=$3

    echo "$(date): Process $process_name (PID: $pid) using $mem_usage% memory" | tee -a "$LOG_FILE"

    # Attempt to lower priority (renice)
    echo "$(date): Attempting to lower priority for PID $pid" | tee -a "$LOG_FILE"
    renice +10 -p "$pid" > /dev/null 2>&1

    # Check memory usage again after a short sleep
    sleep 5
    current_mem=$(ps -p "$pid" -o %mem --no-headers | tr -d ' ')

    # If memory usage is still above threshold, kill the process
    if (( $(echo "$current_mem >= $MEMORY_THRESHOLD" | bc -l) )); then
        echo "$(date): Killing process $process_name (PID: $pid) as it still exceeds memory threshold" | tee -a "$LOG_FILE"
        kill -9 "$pid"
    else
        echo "$(date): Process $process_name (PID: $pid) memory usage reduced to $current_mem%" | tee -a "$LOG_FILE"
    fi
}

# Main loop to monitor and regulate memory usage
while true; do
    echo "Monitoring memory usage..." | tee -a "$LOG_FILE"

    # Get processes exceeding memory threshold
    while read -r pid process_name mem_usage; do
        regulate_process "$pid" "$process_name" "$mem_usage"
    done < <(get_top_memory_consumers)

    # Sleep for specified interval
    sleep "$CHECK_INTERVAL"
done
