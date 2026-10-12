#!/bin/sh
# Runs gpu-screen-recorder ("$@") for the shell's Capture service (from the
# nafeel/capture plugin), which reads this
# script's output line by line: "PID <n>" once it starts (the service stops it
# with SIGINT and pauses it with SIGUSR2), the recorder's own messages, then
# "EXIT <status>" when the file is finished. If the service goes away (plugin
# reload, Noctalia restart), the recording is stopped cleanly rather than
# killed, so the file is still playable.
"$@" 2>&1 &
pid=$!
trap 'kill -INT "$pid" 2>/dev/null' INT TERM HUP
echo "PID $pid"
wait "$pid"
status=$?
while kill -0 "$pid" 2>/dev/null; do
    wait "$pid"
    status=$?
done
echo "EXIT $status"
