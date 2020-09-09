# YaST Partitioner - Partial demo of a classical menu

This branch of yast-storage-ng is only useful if you want to play a bit with the
sketch of the classical menu bar.

Execute the demo (that mocks some disks, partitions, MD and LVM devices) by
running this (it's a one-liner bash).

```
./demo.sh
```

So far, the menu is only intended to be used from the system table that lists all
devices. Select the different elements in that table and take a look to how the
menu reacts enabling/disabling the entries that make sense.

![Screenshot of the demo](screenshot.png)

So far, only the following entries really work. Play with them if you please.

  - System
    - Rescan Devices
    - Partitioner Settings
  - Edit
    - Add RAID
    - Add Partition
    - Delete (if the selected device is a partition or a RAID)
  - View
    - Device Graphs
    - Installation Summary
    - Partitions (beware, it will take you out of the system table)
  - Configure
    - All entries
