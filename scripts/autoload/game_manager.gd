# game_manager.gd
# Global game state manager - handles player data, table tiers, and game flow
# This is an autoload/singleton that persists across scenes
class_name GameManagerClass
extends Node

#region Signals
signal balance_changed(new_balance: int)
signal table_unlocked(table_tier: int)
signal bet_placed(amount: int)
signal game_result(result: String, payout: int)
#endregion

#region Constants - Table Tiers
enum TableTier { BEGINNER, STANDARD, HIGH_ROLLER, VIP }

const TABLE_CONFIG: Dictionary = {
	TableTier.BEGINNER: {
		"name": "Beginner Table",
		"min_bet": 10,
		"max_bet": 100,
		"unlock_balance": 0,
		"color": Color(0.2, 0.5, 0.2)  # Dark green
	},
	TableTier.STANDARD: {
		"name": "Standard Table",
		"min_bet": 50,
		"max_bet": 500,
		"unlock_balance": 500,
		"color": Color(0.1, 0.4, 0.6)  # Blue-ish
	},
	TableTier.HIGH_ROLLER: {
		"name": "High Roller Table",
		"min_bet": 100,
		"max_bet": 5000,
		"unlock_balance": 5000,
		"color": Color(0.5, 0.1, 0.1)  # Dark red
	},
	TableTier.VIP: {
		"name": "VIP Table",
		"min_bet": 500,
		"max_bet": 50000,
		"unlock_balance": 50000,
		"color": Color(0.4, 0.3, 0.1)  # Gold-ish
	}
}

# Card values for blackjack
const CARD_VALUES: Dictionary = {
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10,
	"jack": 10, "queen": 10, "king": 10, "ace": 11
}

const SUITS: Array[String] = ["hearts", "diamonds", "clubs", "spades"]
const RANKS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"]

# Payout multipliers
const BLACKJACK_PAYOUT: float = 1.5  # 3:2
const INSURANCE_PAYOUT: float = 2.0  # 2:1
const NORMAL_WIN_PAYOUT: float = 1.0  # 1:1
#endregion

#region Player State
var player_balance: int = 1000:
	set(value):
		player_balance = max(0, value)
		balance_changed.emit(player_balance)
		_check_table_unlocks()

var current_bet: int = 0
var insurance_bet: int = 0
var current_table: TableTier = TableTier.BEGINNER
var unlocked_tables: Array[TableTier] = [TableTier.BEGINNER]

# Statistics
var stats: Dictionary = {
	"games_played": 0,
	"games_won": 0,
	"games_lost": 0,
	"games_pushed": 0,
	"blackjacks": 0,
	"total_winnings": 0,
	"total_losses": 0,
	"biggest_win": 0,
	"biggest_loss": 0
}
#endregion

#region Lifecycle
func _ready() -> void:
	# Load saved data when game starts
	SaveManager.load_game()
	_check_table_unlocks()
#endregion

#region Balance Management
func add_balance(amount: int) -> void:
	player_balance += amount
	if amount > 0:
		stats.total_winnings += amount
		if amount > stats.biggest_win:
			stats.biggest_win = amount
	SaveManager.save_game()

func subtract_balance(amount: int) -> bool:
	if amount > player_balance:
		return false
	player_balance -= amount
	stats.total_losses += amount
	if amount > stats.biggest_loss:
		stats.biggest_loss = amount
	SaveManager.save_game()
	return true

func place_bet(amount: int) -> bool:
	var table_config: Dictionary = TABLE_CONFIG[current_table]
	if amount < table_config.min_bet or amount > table_config.max_bet:
		return false
	if amount > player_balance:
		return false
	
	current_bet = amount
	player_balance -= amount
	bet_placed.emit(amount)
	return true

func place_insurance() -> bool:
	var insurance_amount: int = current_bet / 2
	if insurance_amount > player_balance:
		return false
	
	insurance_bet = insurance_amount
	player_balance -= insurance_amount
	return true

func can_double_down() -> bool:
	return current_bet <= player_balance

func can_split() -> bool:
	return current_bet <= player_balance

func double_bet() -> bool:
	if not can_double_down():
		return false
	player_balance -= current_bet
	current_bet *= 2
	return true
#endregion

#region Table Management
func _check_table_unlocks() -> void:
	for tier: TableTier in TABLE_CONFIG.keys():
		if tier not in unlocked_tables:
			if player_balance >= TABLE_CONFIG[tier].unlock_balance:
				unlocked_tables.append(tier)
				table_unlocked.emit(tier)

func is_table_unlocked(tier: TableTier) -> bool:
	return tier in unlocked_tables

func set_current_table(tier: TableTier) -> bool:
	if not is_table_unlocked(tier):
		return false
	current_table = tier
	return true

func get_table_config(tier: TableTier = current_table) -> Dictionary:
	return TABLE_CONFIG[tier]
#endregion

#region Game Results
func process_win(is_blackjack: bool = false) -> int:
	var payout: int
	if is_blackjack:
		payout = int(current_bet * BLACKJACK_PAYOUT) + current_bet
		stats.blackjacks += 1
	else:
		payout = int(current_bet * NORMAL_WIN_PAYOUT) + current_bet
	
	player_balance += payout
	stats.games_won += 1
	stats.games_played += 1
	game_result.emit("win", payout)
	_reset_bets()
	SaveManager.save_game()
	return payout

func process_loss() -> void:
	stats.games_lost += 1
	stats.games_played += 1
	game_result.emit("loss", 0)
	_reset_bets()
	SaveManager.save_game()

func process_push() -> int:
	var refund: int = current_bet
	player_balance += refund
	stats.games_pushed += 1
	stats.games_played += 1
	game_result.emit("push", refund)
	_reset_bets()
	SaveManager.save_game()
	return refund

func process_insurance_win() -> int:
	var payout: int = int(insurance_bet * INSURANCE_PAYOUT) + insurance_bet
	player_balance += payout
	insurance_bet = 0
	return payout

func process_insurance_loss() -> void:
	insurance_bet = 0

func process_surrender() -> int:
	var refund: int = current_bet / 2
	player_balance += refund
	stats.games_lost += 1
	stats.games_played += 1
	game_result.emit("surrender", refund)
	_reset_bets()
	SaveManager.save_game()
	return refund

func check_bankruptcy() -> bool:
	var min_possible_bet: int = TABLE_CONFIG[TableTier.BEGINNER].min_bet
	if player_balance < min_possible_bet:
		player_balance = 1000 # Reset to default
		SaveManager.save_game()
		return true
	return false

func _reset_bets() -> void:
	current_bet = 0
	insurance_bet = 0
#endregion

#region Card Utilities
static func get_card_value(rank: String) -> int:
	return CARD_VALUES.get(rank.to_lower(), 0)

static func calculate_hand_value(cards: Array) -> int:
	var total: int = 0
	var aces: int = 0
	
	for card: Dictionary in cards:
		var value: int = get_card_value(card.rank)
		total += value
		if card.rank.to_lower() == "ace":
			aces += 1
	
	# Adjust for aces (change from 11 to 1 if busting)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	
	return total

static func is_blackjack(cards: Array) -> bool:
	return cards.size() == 2 and calculate_hand_value(cards) == 21

static func is_bust(cards: Array) -> bool:
	return calculate_hand_value(cards) > 21

static func is_soft_hand(cards: Array) -> bool:
	# A soft hand contains an ace counted as 11
	var total: int = 0
	var aces: int = 0
	
	for card: Dictionary in cards:
		var value: int = get_card_value(card.rank)
		total += value
		if card.rank.to_lower() == "ace":
			aces += 1
	
	# If we have aces and aren't busting, it's soft
	return aces > 0 and total <= 21

static func can_split_hand(cards: Array) -> bool:
	if cards.size() != 2:
		return false
	return get_card_value(cards[0].rank) == get_card_value(cards[1].rank)
#endregion

#region Save/Load Helpers
func get_save_data() -> Dictionary:
	return {
		"player_balance": player_balance,
		"unlocked_tables": unlocked_tables,
		"stats": stats
	}

func load_save_data(data: Dictionary) -> void:
	player_balance = data.get("player_balance", 1000)
	
	var saved_tables: Array = data.get("unlocked_tables", [TableTier.BEGINNER])
	unlocked_tables.clear()
	for table in saved_tables:
		unlocked_tables.append(table as TableTier)
	
	var saved_stats: Dictionary = data.get("stats", {})
	for key: String in stats.keys():
		if key in saved_stats:
			stats[key] = saved_stats[key]
#endregion
