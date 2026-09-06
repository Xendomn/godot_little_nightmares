extends RefCounted

var has_fuse: bool = false
var fuse_installed: bool = false
var power_on: bool = false
var checkpoint: int = 0
var completed: bool = false

func collect_fuse() -> bool:
	if has_fuse or fuse_installed:
		return false
	has_fuse = true
	return true

func install_fuse() -> bool:
	if not has_fuse or fuse_installed:
		return false
	has_fuse = false
	fuse_installed = true
	return true

func activate_power() -> bool:
	if not fuse_installed or power_on:
		return false
	power_on = true
	return true

func enter_checkpoint(index: int) -> void:
	checkpoint = maxi(checkpoint, clampi(index, 0, 2))

func restore_checkpoint() -> void:
	has_fuse = checkpoint == 1
	fuse_installed = checkpoint == 2
	power_on = checkpoint == 2
	completed = false
