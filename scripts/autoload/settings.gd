extends Node
## Persisted player-facing settings. Captions default ON -- for a
## language-learning game, being able to read along with any VO isn't
## an optional accessibility extra, it's core to the pedagogy.

const SAVE_PATH := "user://settings.cfg"

var master_volume: float = 0.8
var captions_enabled: bool = true

func _ready() -> void:
	_load()
	_apply_audio()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()

func set_captions_enabled(value: bool) -> void:
	captions_enabled = value
	_save()

func _apply_audio() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(master_volume, 0.0001)))

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("accessibility", "captions_enabled", captions_enabled)
	config.save(SAVE_PATH)

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		master_volume = config.get_value("audio", "master_volume", master_volume)
		captions_enabled = config.get_value("accessibility", "captions_enabled", captions_enabled)
