# main_menu.gd
# Main menu with table selection and options
extends Control

#region Node References
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var table_select_button: Button = $VBoxContainer/TableSelectButton
@onready var stats_button: Button = $VBoxContainer/StatsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var balance_label: Label = $BalanceLabel
@onready var table_info_label: Label = $TableInfo
@onready var table_select_popup: Control = $TableSelectPopup
@onready var stats_popup: Control = $StatsPopup
#endregion

#region Lifecycle
func _ready() -> void:
	_connect_signals()
	_update_balance()
	_update_table_info()
	_hide_popups()

func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	table_select_button.pressed.connect(_on_table_select_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	GameManager.balance_changed.connect(_on_balance_changed)
#endregion

#region Button Handlers
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/game_table.tscn")

func _on_table_select_pressed() -> void:
	_show_table_select()

func _on_stats_pressed() -> void:
	_show_stats()

func _on_quit_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()
#endregion

#region Table Selection
func _show_table_select() -> void:
	table_select_popup.visible = true
	_populate_table_list()

func _hide_popups() -> void:
	table_select_popup.visible = false
	stats_popup.visible = false

func _populate_table_list() -> void:
	var table_list: VBoxContainer = table_select_popup.get_node("Panel/TableList")
	
	for child in table_list.get_children():
		child.queue_free()
	
	for tier: GameManagerClass.TableTier in GameManager.TABLE_CONFIG.keys():
		var config: Dictionary = GameManager.TABLE_CONFIG[tier]
		var is_unlocked: bool = GameManager.is_table_unlocked(tier)
		
		var button: Button = Button.new()
		if is_unlocked:
			button.text = "%s ($%d - $%d)" % [config.name, config.min_bet, config.max_bet]
		else:
			button.text = "%s (Unlock at $%d)" % [config.name, config.unlock_balance]
			button.disabled = true
		
		button.custom_minimum_size = Vector2(300, 50)
		button.pressed.connect(_on_table_selected.bind(tier))
		table_list.add_child(button)
	
	# Add close button
	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(_hide_popups)
	table_list.add_child(close_button)

func _on_table_selected(tier: GameManagerClass.TableTier) -> void:
	if GameManager.set_current_table(tier):
		_hide_popups()
		_update_table_info()
#endregion

#region Stats Display
func _show_stats() -> void:
	stats_popup.visible = true
	_populate_stats()

func _populate_stats() -> void:
	var stats_label: RichTextLabel = stats_popup.get_node("Panel/StatsLabel")
	var stats: Dictionary = GameManager.stats
	
	var stats_text: String = """[center][b]Your Statistics[/b][/center]

[b]Games Played:[/b] %d
[b]Games Won:[/b] %d
[b]Games Lost:[/b] %d
[b]Games Pushed:[/b] %d
[b]Blackjacks:[/b] %d

[b]Win Rate:[/b] %.1f%%

[b]Total Winnings:[/b] $%d
[b]Total Losses:[/b] $%d
[b]Net Profit:[/b] $%d

[b]Biggest Win:[/b] $%d
[b]Biggest Loss:[/b] $%d
""" % [
		stats.games_played,
		stats.games_won,
		stats.games_lost,
		stats.games_pushed,
		stats.blackjacks,
		(float(stats.games_won) / max(stats.games_played, 1)) * 100.0,
		stats.total_winnings,
		stats.total_losses,
		stats.total_winnings - stats.total_losses,
		stats.biggest_win,
		stats.biggest_loss
	]
	
	stats_label.text = stats_text
	
	# Add close button if not exists
	var panel: Control = stats_popup.get_node("Panel")
	if not panel.has_node("CloseButton"):
		var close_button: Button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "Close"
		close_button.custom_minimum_size = Vector2(100, 40)
		close_button.pressed.connect(_hide_popups)
		close_button.anchor_left = 0.5
		close_button.anchor_right = 0.5
		close_button.anchor_top = 1.0
		close_button.anchor_bottom = 1.0
		close_button.offset_left = -50
		close_button.offset_right = 50
		close_button.offset_top = -50
		close_button.offset_bottom = -10
		panel.add_child(close_button)
#endregion

#region Helpers
func _update_balance() -> void:
	balance_label.text = "Balance: $%d" % GameManager.player_balance

func _update_table_info() -> void:
	var config: Dictionary = GameManager.get_table_config()
	table_info_label.text = "Current Table: %s ($%d-$%d)" % [config.name, config.min_bet, config.max_bet]

func _on_balance_changed(_new_balance: int) -> void:
	_update_balance()
#endregion
