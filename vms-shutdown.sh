#!/bin/sh
#
# vms-shutdown.sh - Automatically list any running VMs and issue a shutdown
#                   command. Cycling through soft, hard and force commands
#                   until all instances are stopped or shutdown failure occurs.
#
# Copyright 2017 Michael Sutherland
# mike@haphazard.io
# 

# Amount of time to wait before moving to next shutdown method: soft,hard,force 
delay=30;

# Return a list of IDs for any running VMs
list () {

    vms=$(/bin/esxcli vm process list | grep "World ID" | sed -e 's/.*: //g;');

    if [ "$vms" ]; then
        echo ${vms};
        return 1;
    fi

    return 0;    
}

# Issue the shutdown command, requires the shutdown "type" and "id" to shutdown
shutdown () {

    echo -e "Running: /bin/esxcli vm process kill --type=$1 --world-id=$2";
    $(/bin/esxcli vm process kill --type=$1 --world-id=$2);
}

# Gracefully shutdown any VMs found running
vms=$(list); rc=$?;
if [ $rc -eq 0 ]; then 
    echo -e "All VMs are shutdown"
    exit 0; 
else
    for id in ${vms}; do shutdown "soft" $id; done;
    echo -e "Verify ${delay}s wait...";
    sleep ${delay};
fi

# Verify status and hard stop any remaining VMs
vms=$(list); rc=$?;
if [ $rc -eq 0 ]; then
    echo -e "All VMs are shutdown"
    exit 0;
else
    for id in ${vms}; do shutdown "hard" $id; done;
    echo -e "Waiting ${delay}s";
    sleep ${delay};
fi

# Verify status and forcefully shutdown any remaining VMs
vms=$(list); rc=$?;
if [ $rc -eq 0 ]; then
    echo -e "All VMs are shutdown"
    exit 0;
else
    for id in ${vms}; do shutdown "force" $id; done;
    echo -e "Waiting ${delay}s";
    sleep ${delay};
fi

# Show final status or list IDs that failed to shutdown
vms=$(list); rc=$?;
if [ $rc -eq 0 ]; then
    echo -e "All VMs are shutdown"
    exit 0;
else
    for id in ${vms}; do echo -e "Unable to shutdown VM id:: $id"; done;
    exit 1;
fi
