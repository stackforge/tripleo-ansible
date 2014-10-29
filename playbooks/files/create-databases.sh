#!/bin/bash
# Copyright (c) 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -eux
set -o pipefail

PATH=/usr/local/bin/:$PATH
# Execute database creation step although suppress output
# that may contain passwords.
sed -i 's/| mysql$/| mysql --defaults-file=\/mnt\/state\/root\/metadata.my.cnf/' /usr/local/bin/os-db-create
reset-db -c 2>&1 |grep -v "db_pass" |grep -v "os-db-create"
reset-db -m 2>&1 |grep -v "db_pass" |grep -v "os-db-create"
