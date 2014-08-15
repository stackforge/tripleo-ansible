#!/usr/bin/python

import argparse
import json
import os

parser = argparse.ArgumentParser()
parser.add_argument('path', default='/var/lib/os-collect-config/local-data')
parser.add_argument('--deployments-key', default='deployments')

args = parser.parse_args()

for fname in os.listdir(args.path):
    f = os.path.join(args.path, fname)
    with open(f) as infile:
        x = json.loads(infile.read())
        dp = args.deployments_key
        final_list = []
        if dp in x:
            if isinstance(x[dp], list):
                for d in x[dp]:
                    name = d['name']
                    if d.get('group', 'Heat::Ungrouped') in ('os-apply-config', 'Heat::Ungrouped'):
                        final_list.append((name, d['config']))
    for oname, oconfig in final_list:
        with open('%s%s' % (f, oname), 'w') as outfile:
            outfile.write(json.dumps(oconfig))
