#!/bin/bash

set -eux
set -o pipefail

# Get and return the wsrep_local_state.
function get_state() {
    mysql --defaults-file=/mnt/state/root/metadata.my.cnf --socket /var/run/mysqld/mysqld.sock -N -e "SHOW STATUS LIKE 'wsrep_local_state'"|cut -f2
}

# Loop until timed out, exit if wsrep_local_state equals Synced "4"
function wait_for_wsrep_synced() {
    COUNT=0
    while true;
    do
        if [ "4" -eq $(get_state) ]; then
            echo "Local wsrep_local_state has reached Synced, breaking out of loop."
            break
        fi
        echo ".... Sleeping 30 seconds"
        sleep 30
        COUNT=$((COUNT + 1))
        if [ $COUNT -gt 61 ]; then
            echo "Aborting, exiting 1, waited for a 30 minutes.  You can re-attempt this setup using ansible-playbook options --start-at-task or --step."
        fi
    done
}

if ! which mysql &>/dev/null; then
    echo "Failure - MySQL CLI not found"
    exit 1
fi

echo "Beginning MySQL wait - Time: $(date)"
  wait_for_wsrep_synced
echo "Exiting MySQL wait - Time: $(date)"
