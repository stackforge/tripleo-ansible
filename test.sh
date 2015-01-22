#!/bin/bash

set -eu
set -o pipefail

SCRIPT_NAME=$(basename $0)

function show_options () {
    echo "Usage: $SCRIPT_NAME [options]"
    echo
    echo "Options:"
    echo "      -h            -- This help"
    echo "      -c            -- Use pre-existing images for TripleO"
    echo "      -c            -- Skip redeployment of TripleO"
    exit $1
}

OPTS=$(getopt -o c,h,s -n $SCRIPT_NAME -- "$@")

eval set -- ${OPTS}
while true ; do
    case "$1" in
        -c) USE_CACHE='-c'; shift 1;;
        -s) SKIP_DEPLOY='0'; shift 1;;
        -h) show_options 0;;
        --) shift ; break ;;
        *) echo "Error: unsupported option $1." ; show_options 1;;
    esac
done

set -x 

# Variables
export TRIPLEO_ROOT=${TRIPLEO_ROOT:-"~/tripleo_root"}
export DIB_COMMON_ELEMENTS="stackuser use-ephemeral restore-ssh-host-keys disable-os-collect-config"
export TE_DATAFILE="$TRIPLEO_ROOT/te_datafile.json"
export USE_CACHE=${USE_CACHE:-''}
export SKIP_DEPLOY=${SKIP_DEPLOY:-'1'}

# Funcitons

#Deploy tripleo
function purge_known_hosts() {
    local NETWORK=$(os-apply-config -m $TE_DATAFILE --key baremetal-network.cidr --type raw --key-default '192.0.2.0/24'|cut -f 1-3 -d.)
    for i in {1..254}; do
        ssh-keygen -R ${NETWORK}.$i;
    done
}

function deploy_tripleo() {
    local USE_CACHED_IMAGES=${1:-''}

    if [ -z ${USE_CACHED_IMAGES} ]; then
        if [ -d "${TRIPLEO_ROOT}/tripleo-incubator" ]; then
            pushd ${TRIPLEO_ROOT}/tripleo-incubator
            git checkout master
            git pull --ff-only
        else
            pushd ${TRIPLEO_ROOT}
            git clone https://git.openstack.org/openstack/tripleo-incubator
        fi
        popd
    fi #End if USE_CACHED_IMAGES

    # Build TripleO
    pushd ${TRIPLEO_ROOT}
    purge_known_hosts
    ./tripleo-incubator/scripts/devtest.sh --trash-my-machine ${USE_CACHED_IMAGES}
    popd
} # End deploy_tripleo

function run_upgrade_sequence() {
    echo "Tagging hosts with metadata in order to execute the update."
    ./scripts/inject_nova_meta.bash
    echo "Populating vars"
    ./scripts/populate_image_vars

    # Attempt to connect to all hosts in order to add any unknown keys
    # as to not prompt during the upgrade sequence
    echo "Testing connectivity to all nodes"
    ANSIBLE_HOST_KEY_CHECKING=False ansible -o -i plugins/inventory/heat.py -u heat-admin -m ping all

    echo "Executing pre-flight check"
    ansible-playbook -vvvv -i plugins/inventory/heat.py -u heat-admin playbooks/pre-flight_check.yml

    echo "Executing upgrade sequence"
    ansible-playbook -vvvv -i plugins/inventory/heat.py -u heat-admin playbooks/update_cloud.yml -e force_rebuild=true

} # End run_upgrade_sequence

function run_compute_online_upgrade() {
    date
    echo "Executing upgrade sequence"
    ansible-playbook -vvvv -i plugins/inventory/heat.py -u heat-admin playbooks/update_cloud.yml -e force_rebuild=true -e online_upgrade=true -l nova-compute
}

function restart_demo_vm() {
    date
    source $TRIPLEO_ROOT/tripleo-incubator/overcloudrc
    nova list --all-tenants
    sleep 300
    nova list --all-tenants
    local INSTANCE_ID=$(nova --os-tenant-name demo list --name demo --minimal|grep demo |awk '{print $2}')
    nova start ${INSTANCE_ID}
}

function ping_demo_vm() {
    date
    source $TRIPLEO_ROOT/tripleo-incubator/overcloudrc
    local FLOATING_IP=$(neutron --os-tenant-name demo floatingip-list -f csv -c floating_ip_address| awk -F'"' 'ENDFILE {print $2}')
    wait_for -w 600 -d 10 -- ping -c 1 ${FLOATING_IP}
    date
}

#Main

# Load Tripleo variabes
source $TRIPLEO_ROOT/tripleo-incubator/scripts/devtest_variables.sh

# Deploy TripleO to the local system.
if [ ${SKIP_DEPLOY} -eq 1 ]; then
    deploy_tripleo ${USE_CACHE}
fi

#TODO: Place files on the ephemeral disk space to check the existance of after the upgrade.
#TODO: Check files on the ephemeral disk
#TODO: Consider Cinder volume attachment
#TODO: Consider updating images in glance with a marker file to ensure that the new image is deployed.

# Load Seed Credentials and upgrade the undercloud!
source  ${TRIPLEO_ROOT}/tripleo-incubator/seedrc
run_upgrade_sequence

# Load Undercloud Credentials and update the overcloud!
source  ${TRIPLEO_ROOT}/tripleo-incubator/undercloudrc
run_upgrade_sequence

# Wait 5 minutes
sleep 300

#TODO: Repeate ephermeral disk file creation/check
restart_demo_vm
# Ping the demo VM after the upgrade
ping_demo_vm

#TODO: Consider testing rebuild of demo VM.. but check code path for ironic.

# Execute an online upgrade of the compute node
source  ${TRIPLEO_ROOT}/tripleo-incubator/undercloudrc
run_compute_online_upgrade

# Attempt to ping the demo VM after the online upgrade attempt on the compute node
ping_demo_vm
