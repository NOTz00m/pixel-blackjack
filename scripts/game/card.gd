# card.gd
# Individual playing card with visual representation and flip animation
class_name Card
extends Node2D

#region Signals
signal flip_completed
signal deal_completed
#endregion

#region Exported Properties
@export var card_width: int = 64
@export var card_height: int = 96
@export var flip_duration: float = 0.3
@export var deal_duration: float = 0.4
@export var target_card_width: float = 60.0  # Target display width in pixels
#endregion

#region Card Data
var suit: String = ""
var rank: String = ""
var is_face_up: bool = false
var card_value: int = 0
var card_scale: float = 1.0
#endregion

#region Node References
@onready var front_sprite: Sprite2D = $FrontSprite
@onready var back_sprite: Sprite2D = $BackSprite
#endregion

#region Lifecycle
func _ready() -> void:
	_update_visibility()
#endregion

#region Initialization
func setup(card_rank: String, card_suit: String, face_up: bool = false) -> void:
	rank = card_rank
	suit = card_suit
	is_face_up = face_up
	card_value = GameManager.get_card_value(rank)
	
	_load_card_textures()
	_update_visibility()
	_apply_scale()

func _apply_scale() -> void:
	# Scale cards to fit the game table (original cards are 655x930)
	if front_sprite.texture:
		var original_width: float = front_sprite.texture.get_width()
		card_scale = target_card_width / original_width
		scale = Vector2(card_scale, card_scale)

func _load_card_textures() -> void:
	var suit_map: Dictionary = {
		"hearts": "Hearts",
		"clubs": "Clovers",
		"spades": "Pikes",
		"diamonds": "Tiles"
	}
	
	# Convert rank to your asset naming: A for ace, face cards capitalized
	var rank_map: Dictionary = {
		"ace": "A",
		"jack": "Jack",
		"queen": "Queen",
		"king": "King"
	}
	
	var mapped_suit: String = suit_map.get(suit.to_lower(), suit)
	var mapped_rank: String = rank_map.get(rank.to_lower(), rank)
	
	# Card style: "black" or "white" - using black by default
	var card_style: String = "black"
	
	# Build path: e.g., "res://assets/playing_cards/black/Hearts_A_black.png"
	var front_path: String = "res://assets/playing_cards/%s/%s_%s_%s.png" % [card_style, mapped_suit, mapped_rank, card_style]
	
	if ResourceLoader.exists(front_path):
		front_sprite.texture = load(front_path)
	else:
		push_warning("Card texture not found: " + front_path)
	
	# Load back texture - use the g3771.png which appears to be a card back
	var back_path: String = "res://assets/playing_cards/%s/g3771.png" % card_style
	if ResourceLoader.exists(back_path):
		back_sprite.texture = load(back_path)
	else:
		# Fallback to a solid color if no back image
		push_warning("Card back texture not found: " + back_path)

func _update_visibility() -> void:
	if front_sprite and back_sprite:
		front_sprite.visible = is_face_up
		back_sprite.visible = not is_face_up
#endregion

#region Animations
func flip(to_face_up: bool = true) -> void:
	if is_face_up == to_face_up:
		flip_completed.emit()
		return
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Store original scale to restore after flip
	var original_scale_x: float = scale.x
	
	# First half: scale X to 0 (card appears to turn sideways)
	tween.tween_property(self, "scale:x", 0.0, flip_duration / 2.0)
	
	# At midpoint, swap visibility
	tween.tween_callback(_swap_face.bind(to_face_up))
	
	# Second half: scale X back to original (not 1.0!)
	tween.tween_property(self, "scale:x", original_scale_x, flip_duration / 2.0)
	
	tween.tween_callback(func(): flip_completed.emit())

func _swap_face(to_face_up: bool) -> void:
	is_face_up = to_face_up
	_update_visibility()

func deal_to(target_position: Vector2, start_position: Vector2, delay: float = 0.0) -> void:
	position = start_position
	modulate.a = 0.0
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	if delay > 0:
		tween.tween_interval(delay)
	
	# Fade in and move simultaneously
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_position, deal_duration)
	tween.tween_property(self, "modulate:a", 1.0, deal_duration * 0.5)
	
	tween.set_parallel(false)
	tween.tween_callback(func(): deal_completed.emit())

func slide_to(target_position: Vector2, duration: float = 0.3) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_position, duration)

func shake() -> void:
	var original_pos: Vector2 = position
	var tween: Tween = create_tween()
	
	for i in range(3):
		tween.tween_property(self, "position:x", original_pos.x + 5, 0.05)
		tween.tween_property(self, "position:x", original_pos.x - 5, 0.05)
	
	tween.tween_property(self, "position", original_pos, 0.05)

func highlight(enabled: bool = true) -> void:
	var tween: Tween = create_tween()
	if enabled:
		tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.0), 0.2)
	else:
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)
#endregion

#region Utility
func get_card_data() -> Dictionary:
	return {
		"rank": rank,
		"suit": suit,
		"value": card_value
	}

func _to_string() -> String:
	return "%s of %s" % [rank, suit]
#endregion
