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

Please see the `ansible` element in `tripleo-image-elements`

The following patches are required for operation:

 * Allow using non-default collectors (openstack/os-collect-config)
   - https://review.openstack.org/#/c/114116/2 - This is a bugfix for
   os-collect-config.
 * Add nova metadata for group (openstack/tripleo-heat-templates) -
   https://review.openstack.org/#/c/113358/2 - This heat template update
   labels instances such that the ansible tools can group the instances
   into groups to facilitate the updates.
 * Make signal_transport a parameter (openstack/tripleo-heat-templates)
   - https://review.openstack.org/#/c/113408/2 - Parameterizes
   signal_transport to allow updates to occur other than via Heat.
 * Element to restore ssh keys from
   /mnt/state (openstack/tripleo-image-elements) -
   https://review.openstack.org/#/c/114360/ - This includes a new image
   element, named restore-ssh-host-keys, which is intended to restore host
   keys preserved by the ansible scripts after a reboot.
 * Addition of basic ansible install - (gozer: hp/tripleo-ansible)
   https://review.hpcloud.net/#/c/37333/ - This includes a new
   image element, named ansible, installs v1.7.0 of ansible to
   /opt/stack/venvs/ansible/, and places symlinks for ansible and
   ansible-playbook to /usr/local/bin to allow for easy program execution.
 * Add tripleo-ansible to /opt/stack - (gozer: hp/tripleo-ansible)
   https://review.hpcloud.net/#/c/37341 - This includes a new image element,
   named tripleo-ansible, which can be included in seed and undercloud
   image builds to allow the tripleo-ansible tools to be automatically
   deployed for use.

The following patches are HIGHLY recommended:

 * Allow rebuild of node in ERROR and DEPLOYFAIL state -
   (openstack/ironic) https://review.openstack.org/#/c/114281/3  It should
   be noted that the upstream PTL has seen it and while it lacks tests so
   can't land right now, it is acceptable to upstream at an existential
   level.

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
        
You will now want to utilize the image ID values observed in the previous
step, and execute the ansible-playbook command with the appropriate values
subsituted into place.  Current variables for passing the image variables
in are nova_compute_rebuild_image_id and controller_rebuild_image_id
which are passed into the chained playbook.
     
    ansible-playbook -vvvv -u heat-admin -M library/cloud -i plugins/inventory/heat.py -e nova_compute_rebuild_image_id=1ae9fe6e-c0cc-4f62-8e2b-1d382b20fdcb -e controller_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc -e controllermgmt_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc -e swift_storage_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc playbooks/update_cloud.yml
     
Below, we break down the above command so you can see what each part does:  
                 
 * -vvvv - Make Ansible very verbose.
 * -u heat-admin - Utilize the heat-admin user to connect to the remote machine.
 * -M library/cloud - Sets the module location so the modules load for the playbooks to execute.
 * -i plugins/inventory/heat.py - Sets the inventory plugin.
 * -e nova_compute_rebuild_image_id=1ae9fe6e-c0cc-4f62-8e2b-1d382b20fdcb - Sets the compute node image ID.
 * -e controller_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc - Sets the controller node image ID.
 * -e controllermgmt_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc - Sets the storage node image ID.
 * -e swift_storage_rebuild_image_id=2432dd37-a072-463d-ab86-0861bb5f36cc - Sets the storage node image ID.
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
