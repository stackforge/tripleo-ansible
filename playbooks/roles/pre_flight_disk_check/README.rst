Pre-flight disk check
=====================

This role can be used to check for sufficient free disk space on
hosts, and will fail if there is not enough space. The amount of space
may be specified as a fixed amount (in bytes) using the `fail_size`
variable, or as a percentage of the total, using the `fail_percent`
variable. Additionally, mounted filesystems can be excluded by mount
name, if specified, in `exclude_mounts`.

To use the role, either include as usual (to use the default values
specified in defaults/main.yml::

  - hosts: hostgroup
    roles:
      - preflight_disk_check

Or specify your own values when you add the role, as follows::

  - hosts: hostgroup
    roles:
      - { role: preflight_disk_check, fail_percent: 10,
	exclude_mounts: [ "/mnt" ], when: instance_status == "ACTIVE"
	}

This will allow you to easily set different parameters for different
types of hosts in your playbook. Note that only one of `fail_percent`
or `fail_size` will be used.
