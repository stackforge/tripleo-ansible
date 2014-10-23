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
