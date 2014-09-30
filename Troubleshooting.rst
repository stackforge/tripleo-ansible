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

  * Solution:

    * Use `nova list` to determine the IP of the congtrollerMgmt node, then ssh into it::

      ssh heat-admin@$IP

    * Verify MySQL is down by running the mysql client as root. It _should_ fail::

      sudo mysql -e "SELECT 1"

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

    * Start it back up in single node bootstrap mode::

      sudo /etc/init.d/mysql bootstrap-pxc

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
