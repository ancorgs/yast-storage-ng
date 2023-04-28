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
# - All partitions are created in the boot disk by default.
# - It's possible to override that for a particular volume and specify a target disk for it
#
# root_device -> boot disk
# candidate_devices -> [boot_disk]
# allocate_volume_mode -> :auto (is the default)
# Volumes ->
#   Assign weight = 100 for all volumes
#   Assign "disk" to volumes that don't go to the boot disk.
#
# LVM-based proposal
# ####################
#
# - The system VG is created by default in the boot disk
# - It's possible to specify a set of several disks if we want the system VG to (potentially) extend
#   over them (will do it only if necessary). It's even possible to select a disk or set of disks
#   that do not include the boot disk.
# - All LVs are created by default in the system VG
# - It's possible to override that for a particular volume and specify an alternative VG name and
#   a target disk (only one) for it
#
# root_device -> boot disk
# candidate_devices -> disks to be used to allocate the system VG
# allocate_volume_mode -> :auto (is the default)
# Volumes ->
#   Assign weight = 100 for all volumes
#   Assign "separate_vg_name" and "disk" to volumes that don't go to the system VG
#
# Policies to make space
# ######################
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
