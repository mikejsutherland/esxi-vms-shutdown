#!/bin/sh
#
# vms-shutdown.sh - Automatically detect any running VMs and issue a shutdown
#                   command. Cycling through guest shutdown, soft, hard and 
#                   force commands until all instances are stopped or a shutdown
#                   failure occurs.
#
# Copyright 2017 Michael Sutherland
# mike@haphazard.io
# 

# Amount of time to wait before moving to next shutdown method: soft,hard,force 
delay=60;


# Return a list of ids for all running VMs
get_all_vm_ids () {
    ids=$(vim-cmd vmsvc/getallvms | awk '{print $1}' | grep -o '[0-9]\+');
    online_ids="";

    for id in ${ids}; do
        status=$(get_vm_id_status ${id});
        if [ $? -eq 1 ]; then
            online_ids="${online_ids}${id}\n";
        fi
    done

    echo -e ${online_ids};
}

# Return the status of a given VM id
get_vm_id_status () {
    $(vim-cmd vmsvc/power.getstate $1 | egrep -iq "off|suspended");

    if [ $? -eq 1 ]; then
        echo -e "$1: online";
        return 1;
    else
        echo -e "$1: offline";
        return 0;
    fi
}

# Issue a guest shutdown command to a VM id
guest_shutdown () {
    status=$(get_vm_id_status $1);

    if [ $? -eq 1 ]; then
        echo -e "Running: vim-cmd vmsvc/power.shutdown $1";
        $(vim-cmd vmsvc/power.shutdown $1);
    fi
}

# Verify all VM ids are no longer running
verify_all_vm_ids_down () {
    ids=$(get_all_vm_ids);

    if [ "${ids}" ]; then
        for id in ${online_vm_ids}; do 
            echo -e "Failed to shutdown VM id: ${id}";
        done;
        return 1;
    else
        echo -e "All VMs are down";
        return 0;
    fi
}

# Return a list of all running VM process ids
get_all_proc_ids () {
    echo $(/bin/esxcli vm process list | grep "World ID" | sed -e 's/.*: //g;');
}

# Verify the status of a given process id
get_proc_id_status () {
    $(/bin/esxcli vm process list | grep -iq "World ID: $1");

    if [ $? -eq 0 ]; then
        echo -e "$1: online";
        return 1;
    else
        echo -e "$1: offline";
        return 0;
    fi
}

# Issue the process shutdown, requires the "id" and "type" of shutdown
proc_shutdown () {
    status=$(get_proc_id_status $1);

    if [ $? -eq 1 ]; then
        echo -e "Running: /bin/esxcli vm process kill --type=$2 --world-id=$1";
        $(/bin/esxcli vm process kill --type=$1 --world-id=$2);
    fi
}

# Verify all the process ids are no longer running
verify_all_proc_ids_down () {
    ids=$(get_all_proc_ids);

    if [ "${ids}" ]; then
        for id in ${ids}; do 
            echo -n "Failed to shutdown VM proc id: ${id}\n";
        done;
        return 1;
    else
        echo -e "All VMs are shutdown";
        return 0;
    fi
}

# Issue a Guest shutdown for any running VMs
for id in $(get_all_vm_ids); do
    guest_shutdown ${id};
done;

echo -e "Verify ${delay}s wait...";
sleep ${delay};

status=$(verify_all_vm_ids_down);
if [ $? -eq 0 ]; then
    echo -e $status;
    exit 0;
fi


# Shutdown any remaining running VM processes
for type in "soft" "hard" "force"; do

    procs=$(get_all_proc_ids);

    if [ "${procs}" ]; then

        for wid in ${procs}; do
            proc_shutdown "${wid}" "${type}"
        done;

        echo -e "Verify ${delay}s wait...";
        sleep ${delay};

    else 
        echo -e "All VMs are shutdown";
        exit 0; 
    fi

done

# Show final status or list IDs that failed to shutdown
echo -e $(verify_all_proc_ids_down);
exit 1;
