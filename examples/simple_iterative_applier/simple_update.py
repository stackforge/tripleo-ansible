#!/usr/bin/env python
#
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

import ConfigParser
import argparse
import subprocess

parser = argparse.ArgumentParser(description='A foo that bars')
parser.add_argument('-p', dest='playbook', help='main.yml', required=True)
parser.add_argument(
    '-l',
    dest='instances',
    help='instances.txt',
    required=True
)
parser.add_argument(
    '-i',
    dest='inventory',
    help='inventory.ini',
    required=True
)
parser.add_argument(
    '-c',
    dest='configfile',
    help='update_config.cfg',
    required=False,
    default='update_config.cfg'
)

results = parser.parse_args()
config = ConfigParser.RawConfigParser()
config.read(results.configfile)

with open(results.instances) as list:
    for host in list:
        for section in config.sections():
            if section in host:
                hostname = host.strip('\n')
                image_id = config.get(section, 'image_id')
                args = (
                    'ansible-playbook',
                    results.playbook,
                    '-e',
                    "name=%s image_id=%s" % (hostname, image_id),
                    '-i',
                    results.inventory
                )
                print "Executing:"
                print args
                subprocess.call(args)
