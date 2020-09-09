# YaST Partitioner - Partial demo of an explicit menu

This branch of yast-storage-ng is only useful if you want to play a bit with the
sketch of the explicit menu bar that contains one menu per technology.

Execute the demo (that mocks some disks, partitions, MD and LVM devices) by
running this (it's a one-liner bash).

```
./demo.sh
```

So far, the menu is only intended to be used from the system table that lists all
devices. Select the different elements in that table and take a look to how the
menus react enabling/disabling the entries that make sense.

![Screenshot of the demo](screenshot.png)

So far, only the following entries really work. Play with them if you please.

  - System
    - All entries
  - Hard Disk
    - View Partitions (beware, it will take you out of the system table)
  - RAID
    - Add RAID
    - View Partitions (beware, it will take you out of the system table)
    - Delete
  - Partition
    - Add Partition
    - Delete
