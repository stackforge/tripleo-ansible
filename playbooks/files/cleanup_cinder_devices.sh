#!/bin/bash
set -eux

for CINDER_VOLUME in `lvdisplay  | grep cinder-volumes | grep 'LV Path' | awk '{print $3}'`; do
   lvchange -a n $CINDER_VOLUME
done
vgchange -a n