#!/bin/bash
set -eux

for loopdevice in `losetup -a| cut -d ':' -f 1`; do
    losetup --detach $loopdevice
done
