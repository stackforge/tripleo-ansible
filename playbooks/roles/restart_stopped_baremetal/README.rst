role: restart_stopped_baremetal
-------------------------------

The purpose behind this role is to restart a stopped baremetal node,
such as a failed compute node, that has been rebuilt via the update.

The is because ironic returns node to it's previous state after a
rebuild.
