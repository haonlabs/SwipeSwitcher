#!/bin/sh
# Usage: ./bench.sh <process-name> [seconds]
# Samples a running process once per second and prints averages of CPU %, idle wakeups
# (each one pulls the CPU out of low-power idle) and Activity Monitor's "Energy Impact".
# Run the same scenario (idle / cursor+scroll / swipes) for each app you compare.
name=$1
secs=${2:-60}
pid=$(pgrep -x "$name" | head -1) || { echo "$name is not running"; exit 1; }
cpu_before=$(ps -o time= -p "$pid")
top -l $((secs + 1)) -s 1 -pid "$pid" -stats cpu,idlew,power |
  awk -v name="$name" '/^%CPU/ { getline; if (++n > 1) { c += $1; w += $2; p += $3; k++ } }
       END { printf "%s, %ds: CPU %.2f%%  idle wakeups %.1f/s  energy impact %.2f\n", name, k, c/k, w/k, p/k }'
echo "CPU time: $cpu_before -> $(ps -o time= -p "$pid")"
