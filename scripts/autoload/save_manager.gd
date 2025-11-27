# save_manager.gd
# Handles saving and loading player progress using JSON serialization
# This is an autoload/singleton
extends Node

const SAVE_FILE_PATH: String = "user://blackjack_save.json"

#region Save/Load Functions
func save_game() -> void:
	# Optional: Disable saving on web
	if OS.has_feature("web"):
		return

	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_data": GameManager.get_save_data()
	}
	
	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("Game saved successfully!")
	else:
		push_error("Failed to save game: " + str(FileAccess.get_open_error()))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found, starting fresh.")
		return false
	
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open save file: " + str(FileAccess.get_open_error()))
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse save file: " + json.get_error_message())
		return false
	
	var save_data: Dictionary = json.data
	
	if "game_data" in save_data:
		GameManager.load_save_data(save_data.game_data)
		print("Game loaded successfully!")
		return true
	
	return false

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("Save file deleted.")

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)
#endregion
