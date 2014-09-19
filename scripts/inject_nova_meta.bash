#!/bin/bash
# Copyright (c) 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Example
#+--------------------------------------+------------------------------------------------------+--------+------------+-------------+---------------------+
#| ID                                   | Name                                                 | Status | Task State | Power State | Networks            |
#+--------------------------------------+------------------------------------------------------+--------+------------+-------------+---------------------+
#| adab0d97-9777-4a10-a77a-461e2dfbf0b2 | overcloud-ce-controller-SwiftStorage0-gymliwipqeo2   | ACTIVE | -          | Running     | ctlplane=192.0.2.21 |
#| 23732305-9e2b-496e-be03-e8ba2b45ffe5 | overcloud-ce-controller-SwiftStorage1-u2r34etwyko6   | ACTIVE | -          | Running     | ctlplane=192.0.2.24 |
#| 2b17ed0f-d656-41f1-be10-c5a0bb0c3fa5 | overcloud-ce-controller-controller0-wheouferu4ao     | ACTIVE | -          | Running     | ctlplane=192.0.2.27 |
#| 8e080a04-a238-411f-ac7a-754f40ef275b | overcloud-ce-controller-controller1-kt344n4a3ipe     | ACTIVE | -          | Running     | ctlplane=192.0.2.26 |
#| 31c530df-256e-4173-aae8-b4b45c8f8a8a | overcloud-ce-controller-controllerMgmt0-43lsrcv46e3y | ACTIVE | -          | Running     | ctlplane=192.0.2.25 |
#| 616a326d-015c-4a2a-979e-294bf322f50d | overcloud-ce-novacompute1-NovaCompute1-yz5gbaptuja3  | ACTIVE | -          | Running     | ctlplane=192.0.2.28 |
#+--------------------------------------+------------------------------------------------------+--------+------------+-------------+---------------------+
# Quick and dirty tool to set nova meta based on server names.


for server in $(nova list | sed -e 's/ //g' | awk -F\| '/ACTIVE/ { print $2 "++" $3 }') ; do
    id=${server%%++*}
    name=${server##*++}
    case $name in
    *SwiftStorage*)
        group="swift-storage"
        ;;
    *Vsa*)
        group="vsa"
        ;;
    *controllerMgmt*)
        group="controllerMgmt"
        ;;
    *controller*)
        group="controller"
        ;;
    *NovaCompute*)
        group="nova-compute"
        ;;
    *undercloud*)
        group="undercloud"
        ;;
    *)
        group="unknown"
        ;;
    esac
    nova meta $id set group=$group
done
