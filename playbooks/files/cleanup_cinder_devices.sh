#!/bin/bash
set -eux

for CINDER_VOLUME in `dmsetup ls 2>/dev/null | cut -f 1 |grep 'cinder--volumes'|grep -v pool`; do
   dmsetup remove $CINDER_VOLUME
done
vgchange -a n
