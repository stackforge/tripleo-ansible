#!/usr/bin/env python
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

import grp
import optparse
import os
import pwd
import stat


def get_object_ids(file):
    stat_information = os.stat(file)
    return(stat_information.st_uid, stat_information.st_gid)


def get_username_from_uid(old_uid, old_password_file):
    file = open(old_password_file)
    passwd_file = file.readlines()
    for user_entry in passwd_file:
        (
            user,
            passwd,
            uid,
            gid,
            gecos,
            home,
            shell
        ) = user_entry.split(':')
        if old_uid == int(uid):
            return user
    return "ErrUserNotFound"


def get_groupname_from_gid(old_gid, old_group_file):
    file = open(old_group_file)
    group_file = file.readlines()
    for group_entry in group_file:
        (
            group,
            passwd,
            gid,
            members
        ) = group_entry.split(':')
        if old_gid == int(gid):
            return group
    return "ErrUserNotFound"


def get_new_uid(username):
    return pwd.getpwnam(username).pw_uid


def get_new_gid(groupname):
    return grp.getgrnam(groupname).gr_gid


def run_check(object, old_password_file, old_group_file):
    (old_uid, old_gid) = get_object_ids(object)
    old_username = get_username_from_uid(old_uid, old_password_file)
    old_groupname = get_groupname_from_gid(old_uid, old_group_file)
    try:
        new_uid = get_new_uid(old_username)
        new_gid = get_new_gid(old_groupname)
        if old_uid != new_uid:
            if old_username in object:
                return(True, old_username, new_uid, old_groupname, new_gid)
        return(False, old_username, new_uid, old_groupname, old_gid)
    except:
        return(False, old_username, -1, old_groupname, -1)


def recursive_update(directory, new_uid, new_gid):
    os.chown(directory, new_uid, new_gid)
    for root, dirs, files in os.walk(directory):
        for dir in dirs:
            os.chown(os.path.join(root, dir), new_uid, new_gid)
        for file in files:
            os.chown(os.path.join(root, file), new_uid, new_gid)


def main():
    usage = "Usage: %prog -f old_password_file -d directory_to_update"
    parser = optparse.OptionParser(usage)
    parser.add_option(
        "-f",
        action="store",
        default=False,
        dest="old_password_file",
        help="Path to previous system password file"
    )
    parser.add_option(
        "-g",
        action="store",
        default=False,
        dest="old_group_file",
        help="Path to previous system password file"
    )
    parser.add_option(
        "-d",
        action="store",
        default=False,
        dest="directory",
        help="Directory to check and apply permission updates to"
    )
    (options, args) = parser.parse_args()

    if not options.directory:
        print("Error: please define a directory to run the program with -d")
        parser.print_help()
        return -1

    if not options.old_password_file:
        print("Error: please define a directory to run the program with -d")
        parser.print_help()
        return -1

    if not options.old_group_file:
        print("Error: please define a directory to run the program with -d")
        parser.print_help()
        return -1


    for object in os.listdir(options.directory):
        if os.path.isdir(os.path.join(options.directory, object)):
            (changed, old_user, new_uid, old_groupname, new_gid) = run_check(
                os.path.join(options.directory, object),
                options.old_password_file,
                options.old_group_file
            )
            if changed:
                print("Updating %s/%s for ownership to uid %s for %s" % (
                    options.directory,
                    object,
                    new_uid,
                    old_user
                    )
                )
                try:
                    recursive_update(
                        os.path.join(options.directory, object),
                        new_uid,
                        new_gid
                    )
                except:
                    print("Failed to update ownership of %s/%s " % (
                        options.directory,
                        object
                        )
                    )
            else:
                print("ignoring %s/%s" % (
                    options.directory,
                    object
                    )
                )
        else:
            print("Ignoring %s/%s as it is not a directory" % (
                options.directory,
                object
                )
            )

main()
