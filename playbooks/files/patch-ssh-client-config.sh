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

# This turns on an internal heartbeat mechanism in the ssh client
# to prevent the client from believing inactivity is a connection
# failure.
if ! grep -q '^\s*ServerAliveInterval' /etc/ssh/ssh_config; then
    echo "    ServerAliveInterval 30" >>/etc/ssh/ssh_config
fi

# This causes the connection to wait until the defined number of
# heartbeats are missed before terminating the connection.
if ! grep -q '^\s*ServerAliveCountMax' /etc/ssh/ssh_config; then
    echo "    ServerAliveCountMax 6" >>/etc/ssh/ssh_config
fi

