#!/bin/bash
PATH=/usr/local/bin/:$PATH

# Execute database creation step although suppress output
# that may contain passwords.
sed -i 's/| mysql$/| mysql --defaults-file=/mnt/state/root/metadata.my.cnf/' /usr/local/bin/sync-db
sync-db -c 2>&1 |grep -v "db_pass" |grep -v "os-db-create"
sync-db -m
