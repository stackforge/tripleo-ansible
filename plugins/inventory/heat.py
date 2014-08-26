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

DOCUMENTATION = '''
---
inventory: heat
short_description: Heat external inventory script
description:
    - Generates inventory that Ansible can understand by making API requests to
      Heat and Nova API
options:
    stack:
        description:
        - Identifier (name or ID) for heat stack to interrogate.
requirements: [ "heatclient" ]
'''

import json
import os
import re
import sys

from oslo.config import cfg

opts = [
    cfg.StrOpt('host', help='List details about the specific host'),
    cfg.BoolOpt('list', help='List active hosts'),
    cfg.MultiStrOpt(
        'stack',
        help='Stack IDs or Names to inspect',
        positional=True
    ),
    cfg.StrOpt('username'),
    cfg.StrOpt('password'),
    cfg.StrOpt('auth-url'),
    cfg.StrOpt('project-id'),
    cfg.StrOpt('group-regex'),
]

try:
    from heatclient.v1 import client as heat_client
except ImportError:
    print('heatclient is required')
    sys.exit(1)
try:
    from novaclient.v1_1 import client as nova_client
except ImportError:
    print('novaclient is required')
    sys.exit(1)

try:
    from keystoneclient.v3 import client as keystone_client
except ImportError:
    print('keystoneclient is required')
    sys.exit(1)


def _parse_config():
    default_config = os.environ.get('HEAT_INVENTORY_CONFIG')
    if default_config:
        default_config = [default_config]

    configs = cfg.ConfigOpts()
    configs.register_cli_opts(opts)
    configs(prog='heat-ansible-inventory',
            default_config_files=default_config)
    if configs.auth_url is None:
        if "OS_AUTH_URL" in os.environ:
            configs.auth_url = os.environ.get('OS_AUTH_URL')
    if configs.username is None:
        if "OS_USERNAME" in os.environ:
            configs.username = os.environ.get('OS_USERNAME')
    if configs.password is None:
        if "OS_PASSWORD" in os.environ:
            configs.password = os.environ.get('OS_PASSWORD')
    if configs.project_id is None:
        if "OS_TENANT_NAME" in os.environ:
            configs.project_id = os.environ.get('OS_TENANT_NAME')
    if '/v2.0' in configs.auth_url:
        configs.auth_url = configs.auth_url.replace('/v2.0', '/v3')
    return configs


class HeatInventory(object):
    def __init__(self, configs):
        self.configs = configs
        self._ksclient = None
        self._hclient = None
        self._nclient = None

    @property
    def stacks(self):
        if not self.configs.stack:
            return self.hclient.stacks.list()
        else:
            return [
                self.hclient.stacks.get(stack) for stack in self.configs.stack
            ]

    def list(self):
        hostvars = {}
        groups = {}
        # XXX: need to config access details
        for stack_obj in self.stacks:
            if stack_obj.status != 'COMPLETE':
                print("%s stack is incomplete, in state %s" % (
                    stack_obj.identifier,
                    stack_obj.status
                ))
                sys.exit(1)
            stack_id = stack_obj.id
            for res in self.hclient.resources.list(stack_id):
                if res.resource_type == 'OS::Nova::Server':
                    server = self.nclient.servers.get(res.physical_resource_id)
                    private = [
                        x['addr'] for x in getattr(
                            server,
                            'addresses'
                        ).itervalues().next()
                        if x['OS-EXT-IPS:type'] == 'fixed'
                    ]
                    if private:
                        private = private[0]
                    public = [
                        x['addr'] for x in getattr(
                            server,
                            'addresses'
                        ).itervalues().next()
                        if x['OS-EXT-IPS:type'] == 'floating']

                    if public:
                        public = public[0]
                    addr = server.accessIPv4 or public or private
                    groups[res.physical_resource_id] = [addr]
                    groups[server.name] = [addr]
                    if self.configs.group_regex:
                        group_name = re.search(
                            self.configs.group_regex, res.resource_name
                        )
                        if group_name:
                            group_name = group_name.group(0)
                            if group_name in groups:
                                groups[group_name].append(addr)
                            else:
                                groups[group_name] = [addr]
                    if 'group' in server.metadata:
                        group_name = server.metadata['group']
                        if group_name in groups:
                            groups[group_name].append(addr)
                        else:
                            groups[group_name] = [addr]
                    hostvars[addr] = {
                        'heat_metadata': self.hclient.resources.metadata(
                            stack_id,
                            res.resource_name
                        )
                    }
                    hostvars[addr]['instance_status'] = server.status
                    hostvars[addr]['instance_image_id'] = server.image['id']
                    hostvars[addr]['instance_id'] = res.physical_resource_id
        inventory = {'_meta': {'hostvars': hostvars}}
        inventory.update(groups)
        print(json.dumps(inventory, indent=2))

    def host(self):
        hostvars = {}

        for stack_obj in self.stacks:
            if stack_obj.status != 'COMPLETE':
                print("%s stack is incomplete, in state %s" % (
                    stack_obj.identifier,
                    stack_obj.status
                ))
                sys.exit(1)
            stack_id = stack_obj.id
            for res in self.hclient.resources.list(stack_id):
                if res.resource_type == 'OS::Nova::Server':
                    server = self.nclient.servers.get(res.physical_resource_id)
                    if self.configs.host in server.name:
                        hostvars = {
                            'heat_metadata': self.hclient.resources.metadata(
                                stack_id,
                                res.resource_name
                            )
                        }
                        hostvars['instance_status'] = server.status
                        hostvars['instance_image_id'] = server.image['id']
                        hostvars['instance_id'] = res.physical_resource_id
                        print(json.dumps(hostvars, indent=2))
            break

    @property
    def ksclient(self):
        if self._ksclient is None:
            self._ksclient = keystone_client.Client(
                auth_url=self.configs.auth_url,
                username=self.configs.username,
                password=self.configs.password)
            self._ksclient.authenticate()
        return self._ksclient

    @property
    def hclient(self):
        if self._hclient is None:
            ksclient = self.ksclient
            endpoint = ksclient.service_catalog.url_for(
                service_type='orchestration', endpoint_type='publicURL')
            self._hclient = heat_client.Client(
                endpoint=endpoint,
                token=ksclient.auth_token)
        return self._hclient

    @property
    def nclient(self):
        if self._nclient is None:
            ksclient = self.ksclient
            endpoint = ksclient.service_catalog.url_for(
                service_type='compute', endpoint_type='publicURL')
            self._nclient = nova_client.Client(
                bypass_url=endpoint,
                username=None,
                api_key=None,
                project_id=self.configs.project_id,
                auth_url=self.configs.auth_url,
                auth_token=ksclient.auth_token)
        return self._nclient


def main():
    configs = _parse_config()
    hi = HeatInventory(configs)
    if configs.list:
        hi.list()
    elif configs.host:
        hi.host()
    sys.exit(0)

if __name__ == '__main__':
    main()
