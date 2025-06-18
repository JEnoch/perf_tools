#!/bin/bash


if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with 'sudo' as such:"
    echo "  sudo $0 $*"
    exit 1
fi
REAL_USERNAME=$SUDO_USER

FLAMEGRAPH_DIR=${FLAMEGRAPH_DIR:-/home/$REAL_USERNAME/perf_tools/FlameGraph}
if [ ! -d "$FLAMEGRAPH_DIR" ]; then
    echo "Cannot find FlameGraph in $FLAMEGRAPH_DIR"
    exit 1
fi

DATE=`date +%Y-%m-%d-%H%M`
DIR=$PWD/$DATE
mkdir -p $DIR

echo "Saving perf in $DIR"
cd $DIR

start_perf() {
    perf record -F 99 -a -g &
    PERF_PID=$!
    echo "perf running with pid: $PERF_PID"
}


stop_perf() {
    echo "Stopping perf"
    kill -SIGINT $PERF_PID
    elapsed=0
    while kill -0 $PERF_PID 2>/dev/null; do
        sleep 1
        ((elapsed++))
        if [ $elapsed == 120 ]; then
            echo "perf didn't stop gracefully - killing it"
            kill -9 $PERF_PID
            return
        fi
    done
}

treat_perf_data() {
    echo "Treating perf.data"
    perf script > perf.scripted
    # Aggregate all Tokio "rx-??" tasks in only one "rx-ZZ" task
    sed -i 's%^rx-.. %rx-ZZ %g' perf.scripted
    $FLAMEGRAPH_DIR/stackcollapse-perf.pl perf.scripted > perf.folded
    $FLAMEGRAPH_DIR/flamegraph.pl perf.folded > perf.svg
}



ATOP_SAMPLE_INTERVAL=${ATOP_SAMPLE_INTERVAL:-0.5}

start_atop() {
    atop -w host.atop 0 &
    ATOP_PID=$!
    echo "atop running with pid: $ATOP_PID"
}

sample_atop() {
    kill -SIGUSR1 $ATOP_PID
}

stop_atop() {
    echo "Stopping atop"
    kill -SIGUSR2 $ATOP_PID
    while kill -0 $ATOP_PID 2>/dev/null; do
        sleep 1
        ((elapsed++))
        if [ $elapsed == 10 ]; then
            echo "atop didn't stop gracefully - killing it"
            kill -9 $ATOP_PID
            return
        fi
    done
}

stop_all() {
    kill -SIGINT $PERF_PID
    stop_perf
    treat_perf_data
    chown -R $REAL_USERNAME:$REAL_USERNAME .
    exit 0
}
trap stop_all SIGINT

start_perf
start_atop

echo "Press Ctrl+C to stop measurement $ATOP_SAMPLE_INTERVAL"
while true; do
    sleep $ATOP_SAMPLE_INTERVAL
    sample_atop
done
