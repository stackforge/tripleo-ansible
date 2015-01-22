#!/bin/bash

set -eux

# Variables
export TRIPLEO_ROOT=${TRIPLEO_ROOT:-"~/tripleo_root"}
export DIB_COMMON_ELEMENTS="stackuser use-ephemeral restore-ssh-host-keys disable-os-collect-config"
export TE_DATAFILE="$TRIPLEO_ROOT/te_datafile.json"
# Funcitons

function restart_demo_vm{} {
    local INSTANCE_ID=$(nova list --all-tenants --name demo --minimal|grep demo |awk '{print $2}')
}

#deploy tripleo
function deploy_tripleo() {
    if [ -d "${TRIPLEO_ROOT}/tripleo-incubator" ]; then
        pushd ${TRIPLEO_ROOT}/tripleo-incubator
        git checkout master
        git pull --ff-only
    else
        pushd ${TRIPLEO_ROOT}
        git clone https://git.openstack.org/openstack/tripleo-incubator
    fi
    popd

    pushd ${TRIPLEO_ROOT}
    # Setup tripleo_image_elements for disable-os-collect-config
    if [ ! -d "${TRIPLEO_ROOT}/tripleo-image-elements"]; then
        git clone https://git.openstack.org/openstack/tripleo-image-elements
    fi
    if [ -x "$TRIPLEO_ROOT/tripleo-image-elements"]; then
        git checkout master
        git pull --ff-only
    fi
    popd

    # Build TripleO
    pushd ${TRIPLEO_ROOT}
    ./tripleo-incubator/scripts/devtest.sh --trash-my-machine
    popd
} # End deploy_tripleo

function run_upgrade_sequence() {
    echo "Tagging hosts with metadata in order to execute the update."
    ./scipts/inject_nova_meta.bash
    echo "Populating vars"
    ./scripts/populate_image_vars

    # Attempt to connect to all hosts in order to add any unknown keys
    # as to not prompt during the upgrade sequence
    echo "Testing connectivity to all nodes"
    ANSIBLE_HOST_KEY_CHECKING=False ansible -o -i plugins/inventory/heat.py -u heat-admin -m ping all

    echo "Executing pre-flight check"
    ansible-playbook -vvvv -M library/cloud -i plugins/inventory/heat.py -u heat-admin playbooks/pre-flight_check.yml

    echo "Executing upgrade sequence"
    ansible-playbook -vvvv -M library/cloud -i plugins/inventory/heat.py -u heat-admin playbooks/update_cloud.yml -e force_rebuild=true

} # End run_upgrade_sequence

function restart_demo_vm() {
    source $TRIPLEO_ROOT/tripleo-incubator/overcloudrc-user
    DEMO_VM_ID=$(nova list --name demo --minimal|grep demo |awk '{print $2}')
    nova start ${DEMO_VM_ID}
}

#Main

# Deploy TripleO to the local system.
deploy_tripleo

#TODO: Place files on the ephemeral disk space to check the existance of after the upgrade.
#TODO: Check files on the ephemeral disk
#TODO: Consider Cinder volume attachment

#Load Seed Credentials and upgrade the undercloud!
.  ${TRIPLEO_ROOT}/tripleo-incubator/seedrc
run_upgrade_sequence

# Load Undercloud Credentials and update the overcloud!
.  ${TRIPLEO_ROOT}/tripleo-incubator/undercloudrc
run_upgrade_sequence

#TODO: Repeate ephermeral disk file creation/check
restart_demo_vm
#TODO: Ping the demo VM
#TODO: Consider testing rebuild of demo VM.. but check code path for ironic.
