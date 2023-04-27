class ProposalSettings
  attr_accessor :multidisk_first

  attr_accessor :use_lvm
  attr_accessor :separate_vgs
  # * :use_available The VG will be created to use all the available space, thus the
  #   VG size could be greater than the sum of LVs sizes.
  # * :use_needed The created VG will match the requirements 1:1, so its size will be
  #   exactly the sum of all the LVs sizes.
  # * :use_vg_size The VG will have a predefined size, that could be greater than the
  #   LVs sizes.
  attr_reader :lvm_vg_strategy
  # @return [DiskSize] if :use_vg_size is specified in the previous option, this will
  #   specify the predefined size of the LVM volume group.
  attr_accessor :lvm_vg_size
  attr_accessor :lvm_vg_reuse

  # Mode to use when allocating the volumes in the available devices
  #
  # When set to :auto, the proposal expects a set of candidate disks in which it will distribute
  # the volumes automatically as needed. If set to :device, the proposal needs to know in which
  # disk must place each volume. As a consequence, the interface presented to the user by default
  # will be different (containing different questions) depending of the value of this property.
  #
  # @return [:auto, :device] :auto by default
  attr_accessor :allocate_volume_mode

  def root_device; end
  def candidate_devices; end

  secret_attr :encryption_password
  attr_accessor :encryption_method
  attr_accessor :encryption_pbkdf

  # Criteria to select if a partition is windows, linux or other:
  #
  # If filesystem.type == bitlocker || libstorage-ng.is_windows?[1]
  #   windows
  # elsif partition.id in [LINUX, SWAP, LVM, RAID]
  #   linux
  # else
  #   other
  # end
  #
  # Criteria to select which partitions to resize:
  # partition.recoverable_size

  attr_accessor :resize_windows
  attr_reader :windows_delete_mode
  attr_reader :linux_delete_mode
  attr_reader :other_delete_mode
  attr_accessor :delete_resize_configurable

  # [1] is Ntfs, Vfat or ExtFat AND contains any of these files:
  #     boot.ini, msdos.sys, io.sys, config.sys, MSDOS.SYS, IO.SYS, bootmgr, $Boot


  attr_accessor :volumes
end

# From Agama to Y2Storage

# Partition-based proposal
# ####################
#
# Volumes -> Assign weight = 1 for all volumes
# root_device -> boot disk
#
# Alternative A
#    allocate_volume_mode -> :device
#    Volumes -> Assign #device to ALL volumes (either "boot disk" or a explicit one). Assigning
#    #device to all volumes is actually the only way to go. The proposal will force a (kind of
#    random) disk for those having a nil device before starting.
#    candidate_devices -> irrelevant. If mode is :device, the readers for
#    ProposalSettings#candidate_devices and #root_device always infere the result from the list
#    of proposed volumes and their respective volume.device
#
# Alternative B
#    allocate_volume_mode -> :auto
#    Volumes -> Assign "disk" to volumes that don't go to the boot disk. That's useless because that
#    setting is ignored if mode is :auto
#    What if we stop ignoring it? -> let's try
#    candidate_devices -> [boot_disk]
#
# Delete everything
#  linux/windows/other_delete_mode -> :all
#
# Keep everything
#  resize_windows -> false
#  linux/windows/other_delete_mode -> :none
#
# Resize
#  resize_windows -> true
#  linux/windows/other_delete_mode -> :none
#  we need to introduce resize_linux and resize_other
#  we may want to make PartitionsDistributionCalculator.resizing_size more agressive
#    -> It only removes the minimim needed space. The max_sizes are not taken into account.
#
# Custom
#  Maybe a different Strategy with completely different settings?


# LVM-based proposal
# ####################
# It's hard to know what possibilities we want to offer for the future. See
# https://trello.com/c/TJo1DYr2/143-storage-lvm-configuration
#
#
# Volumes -> Assign weight = 1 for all volumes
# root_device -> boot disk
#
# Volumes -> Assign "disk" to ALL volumes (either "boot disk" or a explicit one)?
# allocate_volume_mode -> :device. Looks like a requisite for ^^ to be effective
# root_device -> boot dsk
# candidate_devices -> all disks mentioned in the volumes? or only boot_disk?
#
#
#
# Delete everything
#  linux/windows/other_delete_mode -> :all
#
# Keep everything
#  resize_windows -> false
#  linux/windows/other_delete_mode -> :none
#
# Resize
#  resize_windows -> true
#  linux/windows/other_delete_mode -> :none
#  we need to introduce resize_linux and resize_other
#  There is a bug when lvm is used with allocate_volume_mode :device. We ignore forced_disk_name
#  we may want to make PartitionsDistributionCalculator.resizing_size more agressive
#    -> It only removes the minimim needed space. The max_sizes are not taken into account.
#
# Custom
#  Maybe a different Strategy with completely different settings?



# The test case
# sda - 1 TiB
# sdb - 400 GiB
# sdc - 400 GiB
#
# /         -> 5 GiB   - 10 GiB - 30 GiB
# swap      -> 512 MiB - 1 GiB  - 2 GiB
# spacewalk -> 5 GiB   - 15 GiB - unl
# /srv      -> 3 GiB   - 5 GiB  - 10 GiB
#
# lvm-sep-todos
#  - spacewalk -> sda -> 96 GiB
#  - system -> sdb -> 96 GiB desperdiciados
#  - srv    -> sdc -> 96 GiB desperdiciados
