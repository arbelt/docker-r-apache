#!/usr/bin/env bash
#

if [ "$(id -u)" -eq 0 ]; then
    echo "Stepping down to www-data..."
    # allow stdout/stderr to be accessible after stepdown
    chmod o+w /dev/{stdout,stderr}
    exec gosu www-data "${BASH_SOURCE}" "$@"
fi

set -m

tini_running(){
    ps -ef | grep /tini | grep -q -v grep
}

if ! tini_running; then
    if [ $$ = "1" ]; then
        exec /tini -- "${BASH_SOURCE}" "$@"
    else
        # subreaper if not PID 1
        exec /tini -s -- "${BASH_SOURCE}" "$@"
    fi
fi

# PIDs to monitor
declare -A pids

printf "Starting apache... "
/apache.sh &
APACHE_STATUS=$?
pids[apache]=$!

if [ $APACHE_STATUS -ne 0 ]; then
    echo "FAILED"
    exit $APACHE_STATUS
fi

echo "DONE"

args=("$@")

printf "Starting R[${args[*]}]... "

"${args[@]}" &
R_STATUS=$?
if [ $R_STATUS -ne 0 ]; then
    echo "FAILED"
    exit $R_STATUS
fi
pids[R]=$!

echo "DONE"

printf "PIDS: "
for n in "${!pids[@]}"; do printf "[%s:%d] " "${n}" "${pids[$n]}"; done
printf "\n"

while :
do
    sleep 10 &
    wait $!
    for procname in "${!pids[@]}"; do
        ps -p ${pids[$procname]} >/dev/null
        if [ $? -ne 0 ]; then
            printf "Process %s exited\n" "${procname}"
            exit 1
        fi
    done
done
