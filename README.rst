Using Ansible to update images
==============================

This is a new approach to updating an in-place TripleO cloud with new
images. We have chosen Ansible as it allows fine grained control of
the work-flow without requiring one to write any idempotent bash or
python. There are components that are bash or python scripts, and we are
working hard not to replace the whole of TripleO with Ansible, but just
the pieces that make updates more complicated than they need to be.

In general this update process works in the following manner:
    
 * Gather inventory and facts about the deployed cloud from Heat and Nova
 * Quiesce the cloud by shutting down all OpenStack services on
   appropriate nodes
 * Nova-Rebuild nodes using requested image ids
 * Disable os-collect-config polling of Heat
 * Push Metadata from Heat to rebuilt nodes using Ansible and manually
   trigger os-collect-config
 * Start OpenStack services

Installing Ansible
------------------

Ideally the node Ansible is to be executed from was built with the following
disk image elements:

 * ansible
 * tripleo-ansible

Systems that the playbooks are brining up should ideally have the following
disk image elements:

 * restore-ssh-host-keys
 * disable-os-collect-config

If Ansible is not preloaded, it can be installed via `pip install
ansible`  Ansible 1.8.1 or later is required.

If you have manually installed Ansible, see the section on "Setting
the OS Environment" for details on ensuring your dependencies are
met.

Executing Scripts and Playbooks
-------------------------------

All Ansible playbooks and scripts have been written to be run directly
from the tripleo-ansible folder.

An ``ansible.cfg`` file is provided. If you have a systemwide
(/etc/ansible/ansible.conf) or user-specific ( ~/.ansible.cfg) Ansible
config file, then Ansible will not utilize the provided configuration file.

Pre-flight check
----------------

A playbook exists that can be used to check the controllers prior to the
execution of the main playbook in order to quickly identify any issues in
advance.

All controller nodes must be in a healty state (ACTIVE) for the pre flight
checks to pass. We **CANNOT** proceed with an update if a controller node is
down.

    ansible-playbook -vvvv -M library/cloud -i plugins/inventory/heat.py -u heat-admin playbooks/pre-flight_check.yml

Running the updates
-------------------
    
You will want to set your environment variables to the appropriate
values for the following: OS_AUTH_URL, OS_USERNAME, OS_PASSWORD, and
OS_TENANT_NAME

    source /root/stackrc

Your new images will need to be uploaded to glance, such that an instance
can be booted from them, and the image ID will need to be provided to
the playbook as an argument.

You can obtain the ID with the `glance image-list` command, and then
set them to be passed into ansible as arguments.

    glance image-list

It may be possible to infer the image IDs using the script
"populate_image_vars". It will try to determine the latest image for
each image class and set it as a group variable in inventory.

    scripts/populate_image_vars

After it runs, inspect `plugins/inventory/group_vars` and if the data
is what you expect, you can omit the image ids from the ansible command
line below.
        
You will now want to utilize the image ID values observed in the previous
step, and execute the ansible-playbook command with the appropriate values
subsituted into place.  Current variables for passing the image variables
in are nova_compute_rebuild_image_id and controller_rebuild_image_id
which are passed into the chained playbook.
     
    ansible-playbook -vvvv -u heat-admin -i plugins/inventory/heat.py -e nova_compute_rebuild_image_id=1ae9fe6e-c0cc-4f62-8e2b-1d382b20fdcb -e controller_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc -e swift_storage_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc -e vsa_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc playbooks/update_cloud.yml

If you have set the image ids in group vars:

    ansible-playbook -vvvv -u heat-admin -i plugins/inventory/heat.py playbooks/update_cloud.yml
     
Below, we break down the above command so you can see what each part does:  
                 
 * -vvvv - Make Ansible very verbose.
 * -u heat-admin - Utilize the heat-admin user to connect to the remote machine.
 * -i plugins/inventory/heat.py - Sets the inventory plugin.
 * -e nova_compute_rebuild_image_id=1ae9fe6e-c0cc-4f62-8e2b-1d382b20fdcb - Sets the compute node image ID.
 * -e controller_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc - Sets the controller node image ID.
 * -e swift_storage_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc - Sets the swift storage node image ID.
 * -e vsa_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc - Sets the vsa node image ID.
 * playbooks/update_cloud.yml is the path and file name to the ansible playbook that will be utilized.

Upon a successful completion, ansible will print a summary report:
        
            PLAY RECAP ******************************************************************** 
            192.0.2.24 : ok=18 changed=9 unreachable=0 failed=0 
            192.0.2.25 : ok=19 changed=9 unreachable=0 failed=0 
            192.0.2.26 : ok=18 changed=8 unreachable=0 failed=0

Additionally:

As ansible utilizes SSH, you may encounter ssh key errors if the IP
address has been re-used. The fact that SSH keys aren't preserved is a
defect that is being addressed. In order to avoid problems while this
defect is being fixed, you will want to set an environment variable of
"ANSIBLE_HOST_KEY_CHECKING=False", example below.

    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -vvvv -M library/cloud -i plugins/inventory/heat.py -e controller_rebuild_image_id=4bee1a0a-2670-48e4-a3a4-17da6be795cb -e nova_compute_rebuild_image_id=bd20e098-0753-4dc8-8dba-2f739c01ee65 -u heat-admin playbooks/update_cloud.yml

Python, the language that ansible is written in, buffers IO output by default.
This can be observed as long pauses between sudden bursts of log entries where
multiple steps are observed, particullarlly when executed by Jenkins.  This
behavior can be disabled by passing setting the an environment variable of
"PYTHONUNBUFFERED=1", examble below.

    PYTHONUNBUFFERED=1 ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -vvvv -M library/cloud -i plugins/inventory/heat.py -e controller_rebuild_image_id=4bee1a0a-2670-48e4-a3a4-17da6be795cb -e nova_compute_rebuild_image_id=bd20e098-0753-4dc8-8dba-2f739c01ee65 -u heat-admin playbooks/update_cloud.yml

For more information about Ansible, please refer to the documentation at http://docs.ansible.com/

Failure Handling
----------------

Ansible has tunable options to abort the execution of a playbook upon
encountering a failure.

The max_fail_percentage parameter allows users to define what percentage of
nodes can fail before the playbook stops executing. This setting is pre-defined
in the playbook file playbooks/update_cloud.yml. The default value is zero,
which causes the playbook to abort execution if any node fails. You can read
about this option at:
http://docs.ansible.com/playbooks_delegation.html#maximum-failure-percentage

Additionally, it should be noted that the any_errors_fatal variable, when
set to a value of True, will result in ansible aborting upon encountering
any failures.  This variable can be set by adding '-e any_errors_fatal=True'
to the command line.

Additional Options
------------------

The plugins/inventory/group_vars/all file has the following options in order
to tune behavior of the playbook execution.  These options can be enabled by
defining the variable name that they represent on the ansible comamnd line, or
by uncommenting the appropriate line in the plugins/inventory/group-vars/all
file.

 * force_rebuild - This option overrides the logic that prevents an instance
   from being rebuilt if the pre-existing image id maches the id being deployed.
   This may be useful for the purposes of testing.
   Example command line addition: -e force_rebuild=True
 * wait_for_hostkey - This option causes the playbook to wait for the
   SSH host keys to be restored.  This option should only be used if
   the restore-ssh-host-keys element is built into the new image.
 * single_controller - This option is for when a single controller node is
   receiving an upgrade.  It alters the logic so that mysql checks operate
   as if the mysql database cluster is being maintained online by other
   controller nodes during the upgrade. *IF* you are looking at this option
   due to an error indicating "Node appears to be the last node in a cluster"
   then consult Troubleshooting.rst.
 * ssh_timeout - This value, defaulted to 900 [seconds], is the maximum
   amount of time that the post-rebuild ssh connection test will wait for
   before proceeding.
 * pre_hook_command - This, when set to a command, such as /bin/date,
   will execute that command on the host where the playbook is run
   before starting any jobs.
 * post_hook_command - Similar to the pre_hook_command variable, when
   defined, will execute upon the completion of the upgrade job.
 * online_upgrade - This setting tells the script to attempt an online upgrade
   of the node.  At present this is only known to work on compute nodes.

Online Upgrade
--------------

When an upgrade *does not* require a kernel update, the Online Upgrade feature
can be utilized to upgrade compute nodes while leaving their virtual machines
in a running state.  The result is a short one to two minute loss of network
connectivity for the virtual machines as os-refresh-config stops and
restarts key services which causes the loss in network connectivity.

This operation is performed by uploading the new image to the /tmp folder on
the node, syncing file contents over while preserving key files, and then
restarting services.  This is only known to work on compute nodes.

Nova Powercontrol
-----------------

A module named nova_powercontrol has been included which is intended to utilize
nova for all instance power control operations.  This utility module also records
the previous state of the instance and has a special flag which allows the user
to resume or restart all virtual machines that are powered off/suspended upon the
completion of the upgrade if the module is utilized to shut down the instances.

To Use:

From the tripleo-ansible folder, execute the command:

    bash scripts/retrieve_oc_vars

The script will then inform you of a file you need to source into your current
user environment, it will contain the overcloud API credentials utilizing modified
variable names which the playbook knows how to utilize.

    source /root/oc-stackrc-tripleo-ansible

Now that the environment variables are present, add the following to the
ansible-playbook command line for the playbooks to utilize the nova_powercontrol
module:

    -e use_nova_powercontrol=True 

