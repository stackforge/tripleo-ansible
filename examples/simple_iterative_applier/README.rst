A simple iterator for running a playbook.
=========================================

Getting Started
---------------

You will need:
 
 * Stack environment variables loaded.
  
   Example: source $TRIPLEO_ROOT/tripleo-incubator/undercloudrc

 * An Ansible Inventory file defining localhost which makes use of a local connection.  This file is passed in as the -i option to the included script. You can view such a file at ../hosts_local.

  Example Content: "localhost ansible_connection=local"

  More information can be found at http://docs.ansible.com/intro_inventory.html

 * A file containing a list of instances you wish to run the playbook against.

  Example: instances.txt
 
 * A configuration file named update_config.cfg in the folder where your executing the script from.  This file has sections that are based upon a portion of the instance name, such as "controller" and "NovaCompute".  With-in each section is a "image_id" option which is where you would place the new image ID to rebuild the instance with.  Image IDs can be obtained via `glance image-list` once you have the appropriate environment variables loaded.

  Example: update_config.cfg

 * A playbook, expecting expecting the following

   * image_id - glance image id.
   * name - instance name

 * A slightly modified copy of the simeple_rebuild.yml example playbook exists as main.yml

Putting it all together
-----------------------

   source $TRIPLEO_ROOT/tripleo-incubator/undercloudrc

   python ./simple_update.py -p ./main.yml -l instances.txt -i ../hosts_local

A Few notes
-----------

1) The variables defined in main.yml before the tasks level are presently
   redundant, as the underlying nova_rebuild module supports retrieval of the
   configuration from environment variables, although they could be useful for
   modules that do not presently support such functionality, or modules that
   need to execute remotely.

2) If an inventory is populated of each machine into ansible, then it would
   be easy to modify the playbook to connect out and perform actions on each
   instance, such as backup a database, fetch files, replace files, etc.

