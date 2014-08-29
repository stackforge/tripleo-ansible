This is a simplified set of instructions specifically for updating Helion.

 * If you do not have a tripleo-ansible tarball, build one by pulling this
   patch into tripleo-image-elements:
   https://review.hpcloud.net/38796

   And running this, ensuring that t-i-e is in ELEMENT_PATH.

   disk-image-create -u -a amd64 hlinux tripleo-ansible-tarball

 * Copy the tarball to the seed, and untar it in /opt/stack::

   tar -C /opt/stack -cxvf tripleo-ansible-*.tar.gz

 * ssh to the seed as root

 * Determine the undercloud IP

 * Copy stackrc from undercloud to seed::

   ssh heat-admin@$UNDERCLOUD_IP sudo cat /root/stackrc |sed -e 's/localhost/192.0.2.2/' > undercloud-stackrc

 * Activate the ansible virtualenv and cd into tripleo-ansible::

   source /opt/stack/venvs/ansible/bin/activate
   cd /opt/stack/tripleo-ansible

 * Ensure the Nova meta group is set properly on all servers::

   bash scripts/inject_nova_meta.bash

 * From here please refer to README.rst "Running the updates"
