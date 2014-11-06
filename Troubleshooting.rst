Retrying failed actions
=======================

In some cases, steps may fail as some components may not yet be ready for
use due to initialization times, which can vary based on hardware and volume
In the event of this occuring, two options exist that allows a user to
optionally re-attempt or resume playbook executions.

  * Solutions:

    * Ansible ansible-playbook command option --start-at-task="TASK NAME"
      allows resumption of a playbook, when used with the -l limit option.

    * Ansible ansible-playbook command option --step allows a user to confirm
      each task executed by Ansible before it is executed upon.

A node goes to ERROR state during rebuild
=========================================

This can happen from time to time due to network errors or temporary
overload of the undercloud.

  * Symptoms:

    * After error, `nova list` shows node in ERROR

  * Solution:
 
    * Verify hardware is in working order.

    * Get the image ID of the machine with `nova show`::

      nova show $node_id

    * Rebuild manually::

      nova rebuild $node_id $image_id

  * Notes:


MySQL CLI configuration file missing
====================================

Should the post-rebuild restart fail, the possibility exists that the
MySQL CLI configuration file is missing.

  * Symptoms:

    * Attempts to access the MySQL CLI command return an error::

      ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)

  * Solution:

    * Verify that the MySQL CLI config file stored on the state drive
      is present and has content within the file.  You can do this
      by executing the command below to display the contents in your
      terminal.::

      sudo cat /mnt/state/root/metadata.my.cnf

    * If the file is empty, run the command below which will retrieve current
      metadata and update config files on disk.::

      sudo os-collect-config --force --one --command=os-apply-config

    * Verify that the MySQL CLI config file is present in the root user
      directory by executing the following command::

      sudo cat /root/.my.cnf

    * If that file does not exist or is empty, two options exist.

      * Add the following to your MySQL CLI command line::

        --defaults-extra-file=/mnt/state/root/metadata.my.cnf

      * Alternatively, copy configuration from the state drive.::

        sudo cp -f /mnt/state/root/metadata.my.cnf /root/.my.cnf


MySQL fails to start upon retrying update
=========================================

If the update was aborted or failed during the Update sequence before a
single MySQL controller was operational, MySQL will fail to start upon retrying.

  * Symptoms:
    * Update is being re-attempted.

    * The following error messages having been observed.

       * msg: Starting MySQL (Percona XtraDB Cluster) database server: mysqld . . . . The server quit without updating PID file (/var/run/mysqld/mysqld.pid)

       * stderr: ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock' (111)

       * FATAL: all hosts have already failed -- aborting

    * Update automatically aborts.

  * *WARNING*:

    * The command `/etc/init.d/mysql bootstrap-pxc` which is mentioned below
      should only ever be executed when an entire MySQL cluster is down, and
      then only on the last node to have been shut down.  Running this command
      on multiple nodes will cause the MySQL cluster to enter a split brain
      scenario effectively breaking the cluster which will result in
      unpredictable behavior.

  * Solution:

    * Use `nova list` to determine the IP of the congtrollerMgmt node, then ssh into it::

      ssh heat-admin@$IP

    * Verify MySQL is down by running the mysql client as root. It _should_ fail::

      sudo mysql -e "SELECT 1"

    * Attempt to restart MySQL in case another cluster node is online.
      This should fail in this error state, however if it succeeds your
      cluster should again be operational and the next step can be skipped.::

      sudo /etc/init.d/mysql start

    * Start MySQL back up in single node bootstrap mode::

      sudo /etc/init.d/mysql bootstrap-pxc


MySQL/Percona/Galera is out of sync
===================================

OpenStack is configured to store all of its state in a multi-node
synchronous replication Percona XtraDB Cluster database, which uses
Galera for replication. This database must be in sync and have the full
complement of servers before updates can be performed safely.

  * Symptoms:

    * Update fails with errors about Galera and/or MySQL being "Out of Sync"

  * Solution:

    * use `nova list` to determine IP of controllerMgmt node, then SSH to it::
      
      ssh heat-admin@$IP

    * Verify replication is out of sync::

      sudo mysql -e "SHOW STATUS like 'wsrep_%'"

    * Stop mysql::

      sudo /etc/init.d/mysql stop

    * Verify it is down by running the mysql client as root. It _should_ fail::

      sudo mysql -e "SELECT 1"

    * Start controllerMgmt0 MySQL back up in single node bootstrap mode::

      sudo /etc/init.d/mysql bootstrap-pxc

    * On the remaining controller nodes obseved to be having issues, utilize
      the IP address via `nova list` and login to them.::

      ssh heat-admin@$IP

     * Verify replication is out of sync::

      sudo mysql -e "SHOW STATUS like 'wsrep_%'"

    * Stop mysql::

      sudo /etc/init.d/mysql stop

    * Verify it is down by running the mysql client as root. It _should_ fail::

      sudo mysql -e "SELECT 1"

    * Start MySQL back up so it attempts to connect to controllerMgmt0::

      sudo /etc/init.d/mysql start

    * If restarting MySQL fails, then the database is most certainly out of sync
      and the MySQL error logs, located at /var/log/mysql/error.log, will need
      to be consulted.  In this case, never attempt to restart MySQL with
      `sudo /etc/init.d/mysql bootstrap-pxc` as it will bootstrap the host
      as a single node cluster thus worsening what already appears to be a
      split-brain scenario.

MysQL "Node appears to be the last node in a cluster" error
===========================================================

This error occurs when one of the controller nodes does not have MySQL running.
The playbook has detected that the current node is the last running node,
although based on sequence it should not be the last node.  As a result the
error is thrown and update aborted.

  * Symptoms:

    * Update Failed with error message "Galera Replication - Node appears to be the last node in a cluster - cannot safely proceed unless overriden via single_controller setting - See README.rst"

  * Actions:

    * Run the pre-flight_check.yml playbook.  It will atempt to restart MySQL
      on each node in the "Ensuring MySQL is running -" step.  If that step
      succeeeds, you should be able to re-run the playbook and not encounter
      "Node appears to be last node in a cluster" error.

    * IF pre-flight_check fails to restart MySQL, you will need to consult the
      MySQL logs (/var/log/mysql/error.log) to determine why the other nodes
      are not restarting.

SSH Connectivity is lost
========================

Ansible uses SSH to communicate with remote nodes. In heavily loaded, single
host virtualized environments, SSH can lose connectivity.  It should be noted
that similar issues in a physical environment may indicate issues in the
underlying network infrasucture.

  * Symptoms:

    * Ansible update attempt fails.

    * Error output::

      fatal: [192.0.2.25] => SSH encountered an unknown error. The output was:
      OpenSSH_6.6.1, OpenSSL 1.0.1i-dev xx XXX xxxx
      debug1: Reading configuration data /etc/ssh/ssh_config
      debug1: /etc/ssh/ssh_config line 19: Applying options for *
      debug1: auto-mux: Trying existing master
      debug2: fd 3 setting O_NONBLOCK
      mux_client_hello_exchange: write packet: Broken pipe
      FATAL: all hosts have already failed – aborting

  * Solution:

    * You will generally be able to re-run the playbook and complete the
      upgrade, unless SSH connectivity is lost while all MySQL nodes are
      down. (See 'MySQL fails to start upon retrying update' to correct
      this issue.)

    * Early Ubuntu Trusty kernel versions have known issues with KVM which
      will severely impact SSH connectivity to instances. Test hosts should
      have a minimum kernel version of 3.13.0-36-generic.
      The update steps, as root, are::

        apt-get update
        apt-get dist-upgrade
        reboot

    * If this issue is repeatedly encountered on a physical environment, the
      network infrastucture should be inspected for errors.

    * Similar error messages to the error noted in the Symptom may occur with
      long running processes, such as database creation/upgrade steps.  These
      cases will generally have partial program execution log output
      immediately before the broken pipe message visible.

      Should this be the case, Ansible and OpenSSH may need to have their
      configuration files tuned to meet the needs of the environment.

      Consult the Ansible configuration file to see available connection settings
      ssh_args, timeout, and possibly pipelining..::

        https://github.com/ansible/ansible/blob/release1.7.0/examples/ansible.cfg

      As Ansible uses OpenSSH, Please reference the ssh_config manual, in
      paricular the ServerAliveInterval and ServerAliveCountMax options.

Postfix fails to reload
=======================

Occasionally the postfix mail transfer agent will fail to reload because
it is not running when the system expects it to be running.

  * Symptoms:

    * Step in /var/log/upstart/os-collect-config.log shows that 'service postfix reload' failed.

  Solution:

    * Start postfix::

      sudo service postfix start

Apache2 Fails to start
======================

Apache2 requires some self-signed SSL certificates to be put in place
that may not have been configured yet due to earlier failures in the
setup process.

  * Error Message:

    * failed: [192.0.2.25] => (item=apache2) => {"failed": true, "item": "apache2"}
    * msg: start: Job failed to start

  * Symptoms:

    * apache2 service fails to start
    * /etc/ssl/certs/ssl-cert-snakeoil.pem is missing or empty

  * Solution:

    * Re-run `os-collect-config` to reassert the SSL certificates::

      sudo os-collect-config --force --one

RabbitMQ still running when restart is attempted
================================================

There are certain system states that cause RabbitMQ to fail to die on normal kill signals.

  * Symptoms:

    * Attempts to start rabbitmq fail because it is already running

  * Solution:

    * Find any processes running as `rabbitmq` on the box, and kill them, forcibly if need be.

Instance reported with status == "SHUTOFF" and task_state == "powering on"
==========================================================================

If nova atempts to restart an instance when the compute node is not ready,
it is possible that nova could entered a confused state where it thinks that
an instance is starting when in fact the compute node is doing nothing.

  * Symptoms:

    * Command `nova list --all-tenants` reports instance(s) with STATUS ==
      "SHUTOFF" and task_state == "powering on".
    * Instance cannot be pinged.
    * No instance appears to be running on the compute node.
    * Nova hangs upon retrieving logs or returns old logs from the previous
      boot.
    * Console session cannot be established.

  * Solution:

    * On a controller logged in as root, after executing `source stackrc`:

      * Execute `nova list --all-tenants` to obtain instance ID(s)

      * Execute `nova show <instance-id>` on each suspected ID to identify
        suspected compute nodes.

    * Log into the suspected compute node(s) and execute:
      `os-collect-config --force --one`

    * Return to the controller node that you were logged into previously, and
      using the instancce IDs obtained previously, take the following steps.

      * Execute `nova reset-state --active <instance-id>`

      * Execute `nova stop <instance-id>`

      * Execute `nova start <instance-id>`

    * Once the above steps have been taken in order, you should see the
      instance status return to ACTIVE and the instance become accessible
      via the network.

state drive /mnt is not mounted
===============================

In the rare event that something bad happened between the state drive being
unmounted and the rebuild command being triggered, the /mnt volume on the
instance that was being executed upon at that time will be in an unmounted
state.

In such a state, pre-flight checks will fail attempting to start MySQL and
RabbitMQ.

  * Error Messages:

    * Pre-flight check returns an error similar to::

      failed: [192.0.2.24] => {"changed": true, "cmd": "rabbitmqctl -n rabbit@$(hostname) status"
      stderr: Error: unable to connect to node 'rabbit@overcloud-controller0-vahypr34iy2x': nodedown

    * Attempting to manually start MySQL or RabbitMQ return::

      start: Job failed to start

    * Upgrade execution returns with an error indicating::

      TASK: [fail msg="Galera Replication - Node appears to be the last node in a cluster - cannot safely proceed unless overriden via single_controller setting - See README.rst"] ***

  * Symptom:

    * Execution of the `df` command does not show a volume mounted as /mnt.

    * Unable to manually start services.

  * Solution:

    * Execute the os-collect config which will re-mount the state drive. This
      command may fail without additional intervention, however it should mount
      the state drive which is all that is needed to proceed to the next step.::

      sudo os-collect-config --force --one

    * At this point, the /mnt volume should be visible in the output of the `df`
      command.

    * Start MySQL by executing::

      sudo /etc/init.d/mysqld start

    * If MySQL fails to start, and it has been verified that MySQL is not
      running on any controller nodes, then you will need to identify the
      *last* node that MySQL was stopped on and consult the section "MySQL
      fails to start upon retrying update" for guidence on restarting the
      cluster.

    * Start RabbitMQ by executing::

      service rabbitmq-server start

    * If rabbitmq-server fails to start, then the cluster may be down. If
      this is the case, then the *last* node to be stopped will need to be
      identified and started before attempting to restart RabbitMQ on this
      node.

    * At this point, re-execute the pre-flight check, and proceed with the
      upgrade.

VMs may not shut down properly during upgrade
=============================================

During the upgrade process, VMs on compute nodes are shut down
gracefully. If the VMs do not shut down, this can cause the upgrade to
stop.

  * Error Messages:

    * A playbook run ends with a message similar to::

      failed: [10.23.210.31] => {"failed": true} msg: The ephemeral
      storage of this system failed to be cleaned up properly and processes
      or files are still in use. The previous ansible play should have
      information to help troubleshoot this issue.

    * The output of the playbook run prior to this message contains a
      process listing and a listing of open files.

  * Symptoms:

    * The state drive on the compute node, /mnt, is still in use and
      cannot be unmounted. You can confirm this by executing::

      lsof -n | grep /mnt

    * VMs are running on the node. To see which VMs are running, run::

      virsh list

    * If `virsh list` fails, you may need to restart libvirt-bin. Do
      so by running::

      service libvirt-bin restart

  * Solution:

    * Manual intervention is required. You will need to determine why
      the VMs did not shut down properly, and resolve the issue.

    * Unresponsive VMs can be forcibly shutdown using `virsh destroy
      <id>`. Note that this can corrupt filesystems on the VM.

    * Resume the playbook run once the VMs have been shut down.
