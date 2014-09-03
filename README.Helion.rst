This is a simplified set of instructions specifically for updating Helion.

 * IMAGE BUILD (you can skip this if you have a tarball):

   * set TRIPLEO_ROOT to wherever you have tripleo-image-elements, hp-image-elements, and diskimage-builder
     checked out to::

     export TRIPLEO_ROOT=~/build_update
   
   * pull this patch into tripleo-image-elements:

     https://review.hpcloud.net/38796

   * pull this patch into hp-image-elements:

     https://review.hpcloud.net/39168

   * pull this patch into diskimage-builder:

     https://review.openstack.org/118689

   * Set path to seed::

     export DIB_ROOT_IMAGE=path/to/seed.qcow2

   * Set ELEMENTS_PATH::

     export ELEMENTS_PATH=$TRIPLEO_ROOT/diskimage-builder/elements:$TRIPLEO_ROOT/tripleo-image-elements/elements:$TRIPLEO_ROOT/hp-image-elements/elements

   * Use disk-image-create to create a tarball::

     disk-image-create -un -a amd64 image hp-hlinux-apt-repo tripleo-ansible-tarball

   * The tarball should be named 'tripleo-ansible-$hash-$platform-$arch.tar.gz' For example::

     tripleo-ansible-588a134-Debian-GNULinux-cattleprod-amd64.tar.gz

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
