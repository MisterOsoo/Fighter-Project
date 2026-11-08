extends Node
class_name TrainerAI

#region References
@export_group("References")
@export var enemy: BaseEnemy
@export var retreat_component: LowHealthRetreat
#endregion

#region Movement Settings
@export_group("Movement")
@export var preferred_distance: float = 60.0
@export_range(0.05, 5.0, 0.05) var decision_interval: float = 0.15
#endregion

#region Combat Settings
@export_group("Combat")
@export var attack_range: float = 85.0
@export var attack_chance: float = 75.0
@export var heavy_chance: float = 35.0
@export var combo_chance: float = 65.0
@export var attack_cooldown: float = 0.8
@export_group("Attack Approach")
@export_range(0.0, 500.0, 1.0) var attack_approach_distance: float = 20.0
@export_range(0.1, 10.0, 0.1) var approach_timeout: float = 2.0
#endregion

#region Special Attack Settings
@export_group("Special Attacks")
@export var equipped_specials: Array[SpecialAttackData] = []
@export_range(0.0, 100.0, 1.0) var special_chance: float = 35.0
@export_range(0.0, 1000.0, 5.0) var special_range: float = 250.0
@export_range(0.0, 20.0, 0.1) var special_cooldown: float = 3.0
@export_range(0.0, 100.0, 1.0) var ex_special_chance: float = 35.0
@export var debug_specials: bool = false
#endregion

#region Defense Settings
@export_group("Defense")
@export_range(0.0, 100.0, 1.0) var block_chance: float = 75.0
@export_range(0.0, 500.0, 1.0) var block_detection_range: float = 100.0
@export_range(0.05, 2.0, 0.05) var block_hold_duration: float = 0.45
@export_range(0.0, 100.0, 1.0) var crouch_block_chance: float = 25.0
@export_range(0.0, 100.0, 1.0) var counterattack_block_bonus: float = 25.0
@export_range(0.0, 0.5, 0.01) var block_reaction_delay: float = 0.05
@export var debug_defense: bool = false
#endregion

#region Post Attack Recovery
@export_group("Post Attack Recovery")
@export_range(0.0, 5.0, 0.05) var post_attack_pause_min: float = 0.35
@export_range(0.0, 5.0, 0.05) var post_attack_pause_max: float = 0.75
@export var stop_during_recovery: bool = true
#endregion

#region Strategic Retreat
@export_group("Strategic Retreat")
@export var enable_strategic_retreat: bool = true
@export_range(0.0, 100.0, 1.0) var whiff_retreat_chance: float = 55.0
@export_range(0.0, 100.0, 1.0) var blocked_retreat_chance: float = 65.0
@export_range(0.0, 100.0, 1.0) var hit_retreat_chance: float = 20.0
@export_range(0.0, 100.0, 1.0) var back_dash_chance: float = 65.0
@export_range(0.0, 2.0, 0.01) var retreat_delay: float = 0.15
@export_range(0.0, 10.0, 0.1) var retreat_cooldown: float = 2.5
@export_range(0.0, 500.0, 1.0) var minimum_retreat_space: float = 70.0
@export var debug_retreat: bool = false
#endregion

#region Internal Variables
var retreat_cooldown_timer: float = 0.0
var retreat_delay_timer: float = 0.0
var retreat_pending: bool = false
var attack_chain_hit: bool = false
var attack_chain_blocked: bool = false
var tracked_player_block: BlockComponent
var defense_timer: float = 0.0
var was_defending: bool = false
var last_threat_state: State
var last_threat_animation: StringName = &""
var last_threat_frame: int = -1
var threat_was_active: bool = false
var threat_decision_made: bool = false
var threat_reaction_timer: float = 0.0
var decision_timer: float = 0.0
var cooldown_timer: float = 0.0
var approach_timer: float = 0.0
var recovery_timer: float = 0.0
var was_attacking: bool = false
var is_approaching_attack: bool = false
var pending_attack_type: StringName = &"light"
var special_state: EnemySpecialAttackState
var special_cooldown_timer: float = 0.0
var attack_state: EnemyAttackState
var last_combo_attack: AttackData
var combo_decision_made: bool = false
#endregion

#region Initialization
func _ready() -> void:
	if enemy == null:
		var parent: Node = get_parent()
		if parent is BaseEnemy:
			enemy = parent as BaseEnemy
		elif parent != null:
			enemy = parent.get_parent() as BaseEnemy
	if retreat_component == null and enemy != null:
		retreat_component = enemy.get_node_or_null("LowHealthRetreat") as LowHealthRetreat
	find_attack_state()
	find_special_state()
	connect_retreat_signals()

func find_attack_state() -> void:
	attack_state = null
	if enemy == null or enemy.fsm == null:
		return
	for child in enemy.fsm.get_children():
		if child is EnemyAttackState:
			attack_state = child as EnemyAttackState
			return
#endregion

func find_special_state() -> void:
	special_state = null
	if enemy == null or enemy.fsm == null:
		return
	for child in enemy.fsm.get_children():
		if child is EnemySpecialAttackState:
			special_state = child as EnemySpecialAttackState
			return

#region Processing
func _physics_process(delta: float) -> void:
	if enemy == null:
		return
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	special_cooldown_timer = maxf(special_cooldown_timer - delta, 0.0)
	recovery_timer = maxf(recovery_timer - delta, 0.0)
	retreat_cooldown_timer = maxf(retreat_cooldown_timer - delta, 0.0)
	connect_retreat_signals()
	if enemy.is_dead:
		clear_defense()
		cancel_approach()
		enemy.stop_movement()
		was_attacking = false
		retreat_pending = false
		return

	# Detect the end of an attack, including a completed combo chain.
	if was_attacking and not enemy.isAttacking:
		# Interrupted attacks are not completed attack sequences.
		if enemy.isStunned or (enemy.fsm != null and enemy.fsm.current_state is EnemyHurtState):
			retreat_pending = false
		else:
			evaluate_strategic_retreat()
		start_recovery()
		attack_chain_hit = false
		attack_chain_blocked = false
	was_attacking = enemy.isAttacking

	# Defensive reactions remain available throughout post-attack recovery.
	update_defense(delta)
	# Recover from an expired guard request before checking movement eligibility.
	finish_expired_block()
	if enemy.isStunned:
		retreat_pending = false
		clear_defense()
		cancel_approach()
		return
	if enemy.isAttacking:
		if attack_state != null and attack_state.hit_confirmed:
			attack_chain_hit = true
		clear_defense()
		cancel_approach()
		update_combo_decision()
		return
	var defending_now: bool = is_defending()
	if was_defending and not defending_now:
		decision_timer = 0.0
		if debug_defense:
			print(name, ": defense ended; resuming AI decisions")
	was_defending = defending_now
	if defending_now:
		cancel_approach()
		enemy.stop_movement()
		return
	if retreat_pending:
		if process_strategic_retreat(delta):
			return
	if retreat_component != null and retreat_component.should_override_movement():
		cancel_approach()
		enemy.stop_movement()
		return
	if not enemy.can_move():
		cancel_approach()
		return
	if not is_instance_valid(enemy.opponent):
		cancel_approach()
		enemy.stop_movement()
		return

	if recovery_timer > 0.0:
		cancel_approach()
		if stop_during_recovery:
			enemy.stop_movement()
		else:
			update_movement()
		return

	if is_approaching_attack:
		update_attack_approach(delta)
		return
	update_movement()
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = decision_interval
	if try_start_special():
		return
	try_start_attack()

func start_recovery() -> void:
	recovery_timer = randf_range(minf(post_attack_pause_min, post_attack_pause_max), maxf(post_attack_pause_min, post_attack_pause_max))
	cancel_approach()
	decision_timer = decision_interval
	if stop_during_recovery:
		enemy.stop_movement()
	if debug_defense:
		print(name, ": post-attack recovery ", snappedf(recovery_timer, 0.01), "s")
#endregion

#region Strategic Retreat Logic
func connect_retreat_signals() -> void:
	if enemy == null:
		return
	# Hit confirmations are observed directly so a combo's earlier hits
	# are remembered even when EnemyAttackState starts its next attack.
	for node in enemy.find_children("*", "activeFrameHitbox", true, false):
		var hitbox: activeFrameHitbox = node as activeFrameHitbox
		if hitbox != null and not hitbox.hit_confirmed.is_connected(_on_own_hit_confirmed):
			hitbox.hit_confirmed.connect(_on_own_hit_confirmed)
	if not is_instance_valid(enemy.opponent):
		return
	var block: BlockComponent = enemy.opponent.get_node_or_null("BlockComponent") as BlockComponent
	if block == tracked_player_block:
		return
	if is_instance_valid(tracked_player_block) and tracked_player_block.attack_blocked.is_connected(_on_player_blocked):
		tracked_player_block.attack_blocked.disconnect(_on_player_blocked)
	tracked_player_block = block
	if block != null and not block.attack_blocked.is_connected(_on_player_blocked):
		block.attack_blocked.connect(_on_player_blocked)

func _on_own_hit_confirmed(_animation: StringName) -> void:
	if enemy != null and enemy.fsm != null and enemy.fsm.current_state is EnemyAttackState:
		attack_chain_hit = true

func _on_player_blocked() -> void:
	if enemy == null or enemy.fsm == null or not (enemy.fsm.current_state is EnemyAttackState):
		return
	# Confirm the blocking player is our opponent, not a third-party block.
	if not is_instance_valid(enemy.opponent) or tracked_player_block == null:
		return
	if tracked_player_block.get_parent() != enemy.opponent:
		return
	attack_chain_blocked = true

func evaluate_strategic_retreat() -> void:
	retreat_pending = false
	if not enable_strategic_retreat or retreat_cooldown_timer > 0.0:
		return
	if enemy == null or enemy.is_dead or enemy.isStunned:
		return
	var outcome: String = "whiff"
	var chance: float = whiff_retreat_chance
	if attack_chain_hit:
		outcome = "hit"
		chance = hit_retreat_chance
	elif attack_chain_blocked:
		outcome = "blocked"
		chance = blocked_retreat_chance
	if randf() * 100.0 >= chance:
		return
	retreat_pending = true
	retreat_delay_timer = retreat_delay
	if debug_retreat:
		print(name, ": strategic retreat queued after ", outcome)

func process_strategic_retreat(delta: float) -> bool:
	if enemy == null or enemy.is_dead or enemy.isStunned:
		retreat_pending = false
		return false
	if is_defending() or enemy.isAttacking:
		retreat_pending = false
		return false
	if not enemy.is_on_floor():
		retreat_pending = false
		return false
	if not enemy.can_move():
		return true
	retreat_delay_timer = maxf(retreat_delay_timer - delta, 0.0)
	if retreat_delay_timer > 0.0:
		enemy.stop_movement()
		return true
	retreat_pending = false
	if not has_retreat_space():
		return false
	var prefer_dash: bool = randf() * 100.0 < back_dash_chance
	var succeeded: bool = false
	if prefer_dash:
		succeeded = try_back_dash()
		if not succeeded:
			succeeded = try_back_jump()
	else:
		succeeded = try_back_jump()
		if not succeeded:
			succeeded = try_back_dash()
	if succeeded:
		retreat_cooldown_timer = retreat_cooldown
		recovery_timer = 0.0
		cancel_approach()
		if debug_retreat:
			print(name, ": strategic retreat executed")
	return succeeded

func has_retreat_space() -> bool:
	if enemy == null or not is_instance_valid(enemy.opponent):
		return false
	var away: float = -signf(enemy.opponent.global_position.x - enemy.global_position.x)
	if is_zero_approx(away):
		return false
	# A physics ray checks for a solid arena wall before attempting retreat.
	var from_pos: Vector2 = enemy.global_position
	var to_pos: Vector2 = from_pos + Vector2(away * minimum_retreat_space, 0.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.exclude = [enemy.get_rid()]
	query.collision_mask = enemy.collision_mask
	var result: Dictionary = enemy.get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty()

func try_back_dash() -> bool:
	if enemy == null or enemy.fsm == null:
		return false
	var state: EnemyDashState
	for child in enemy.fsm.get_children():
		if child is EnemyDashState:
			state = child as EnemyDashState
			break
	if state == null or not state.can_dash():
		return false
	enemy.dash(EnemyDashState.DashType.BACKWARD)
	return enemy.fsm.current_state == state

func try_back_jump() -> bool:
	if enemy == null or enemy.fsm == null:
		return false
	var state: EnemyJumpState
	for child in enemy.fsm.get_children():
		if child is EnemyJumpState:
			state = child as EnemyJumpState
			break
	if state == null:
		return false
	enemy.jump(EnemyJumpState.JumpType.BACKWARD)
	return enemy.fsm.current_state == state
#endregion

#region Defense Decision
func is_defending() -> bool:
	if enemy == null or enemy.block_component == null:
		return false
	var block: BlockComponent = enemy.block_component
	return block.ai_wants_to_block or block.is_blocking or block.blockstun_timer > 0.0 or block.is_guard_broken

func clear_defense() -> void:
	defense_timer = 0.0
	if enemy != null and enemy.block_component != null:
		enemy.block_component.clear_ai_block()

# Release a stale block after its AI hold and blockstun have both ended.
# This also prevents BaseEnemy.update_block_state() from forcing Block again.
func finish_expired_block() -> void:
	if enemy == null or enemy.block_component == null:
		return
	var block: BlockComponent = enemy.block_component
	if block.use_player_input or block.is_guard_broken:
		return
	if block.ai_wants_to_block or block.blockstun_timer > 0.0:
		return
	if block.is_blocking:
		block.end_block(true)
		if debug_defense:
			print(name, ": cleared expired block flag")
	if enemy.fsm != null and enemy.fsm.current_state is EnemyBlockState:
		if enemy.is_dead or enemy.isStunned:
			return
		if enemy.is_on_floor():
			enemy.fsm.transition_to("idle")
		else:
			enemy.fsm.transition_to("jump")

func reset_threat_tracking() -> void:
	threat_was_active = false
	last_threat_state = null
	last_threat_animation = &""
	last_threat_frame = -1
	threat_decision_made = false
	threat_reaction_timer = 0.0

func update_defense(delta: float) -> void:
	if enemy == null or enemy.block_component == null:
		return
	var block: BlockComponent = enemy.block_component
	if block.use_player_input:
		return
	if enemy.is_dead or enemy.isStunned or block.is_guard_broken:
		clear_defense()
		reset_threat_tracking()
		return

	if defense_timer > 0.0:
		defense_timer = maxf(defense_timer - delta, 0.0)
		if defense_timer <= 0.0:
			block.clear_ai_block()
			if debug_defense:
				print(name, ": block hold expired")

	# Track attacks even when the enemy is temporarily unable to defend.
	# This lets a counterattack be reconsidered once the attack state exits.
	if not is_instance_valid(enemy.opponent):
		reset_threat_tracking()
		return
	var opponent_fsm: FiniteStateMachine = enemy.opponent.get("fsm") as FiniteStateMachine
	if opponent_fsm == null:
		reset_threat_tracking()
		return
	var threat: State = opponent_fsm.current_state
	if not (threat is AttackState or threat is SpecialAttackState):
		reset_threat_tracking()
		return

	var sprite: AnimatedSprite2D = enemy.opponent.get("anim") as AnimatedSprite2D
	var animation: StringName = sprite.animation if sprite != null else &""
	var frame: int = sprite.frame if sprite != null else -1
	var new_threat: bool = (
		not threat_was_active
		or threat != last_threat_state
		or animation != last_threat_animation
		or (frame >= 0 and last_threat_frame > frame)
	)
	if new_threat:
		threat_decision_made = false
		threat_reaction_timer = block_reaction_delay
	threat_was_active = true
	last_threat_state = threat
	last_threat_animation = animation
	last_threat_frame = frame

	if threat_decision_made:
		return
	var distance: float = absf(enemy.opponent.global_position.x - enemy.global_position.x)
	if distance > block_detection_range:
		return
	if enemy.isAttacking or not enemy.is_on_floor():
		return
	if block.ai_wants_to_block or block.is_blocking or block.blockstun_timer > 0.0:
		return
	if enemy.fsm == null or not enemy.fsm.states.has("block"):
		return
	if not enemy.can_move() and not is_approaching_attack:
		return

	# Reaction time starts only once the enemy is actually able to respond.
	threat_reaction_timer = maxf(threat_reaction_timer - delta, 0.0)
	if threat_reaction_timer > 0.0:
		return

	threat_decision_made = true
	var effective_chance: float = block_chance
	if recovery_timer > 0.0:
		effective_chance = minf(100.0, block_chance + counterattack_block_bonus)
	if debug_defense:
		print(name, ": defensive decision at ", snappedf(distance, 0.1), "px; chance=", effective_chance)
	if randf() * 100.0 >= effective_chance:
		if debug_defense:
			print(name, ": chose not to block this attack")
		return

	var crouching: bool = randf() * 100.0 < crouch_block_chance
	cancel_approach()
	enemy.stop_movement()
	enemy.velocity.x = 0.0
	block.request_ai_block(true, crouching)
	defense_timer = block_hold_duration
	enemy.fsm.transition_to("block")
	if enemy.fsm.current_state != enemy.fsm.states["block"]:
		clear_defense()
		if debug_defense:
			print(name, ": block transition rejected")
	elif debug_defense:
		print(name, ": entered ", "crouch block" if crouching else "block")
#endregion

#region Movement Decision
func update_movement() -> void:
	if not is_instance_valid(enemy.opponent):
		enemy.stop_movement()
		return
	var difference: float = enemy.opponent.global_position.x - enemy.global_position.x
	if absf(difference) <= preferred_distance:
		enemy.stop_movement()
	else:
		enemy.set_movement_direction(signf(difference))
#endregion

#region Special Attack Decision
func try_start_special() -> bool:
	if special_state == null:
		find_special_state()
	if special_state == null or equipped_specials.is_empty():
		return false
	if special_cooldown_timer > 0.0 or cooldown_timer > 0.0 or recovery_timer > 0.0:
		return false
	if enemy == null or enemy.is_dead or enemy.isStunned or enemy.isAttacking:
		return false
	if is_defending() or retreat_pending or is_approaching_attack:
		return false
	if not enemy.is_on_floor() or not enemy.can_move():
		return false
	if not is_instance_valid(enemy.opponent):
		return false
	var distance: float = absf(enemy.opponent.global_position.x - enemy.global_position.x)
	if distance > special_range or randf() * 100.0 >= special_chance:
		return false

	var candidates: Array[SpecialAttackData] = []
	for special in equipped_specials:
		if special != null and special.can_use(false):
			candidates.append(special)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	for special in candidates:
		var use_ex: bool = special.ex_enabled and randf() * 100.0 < ex_special_chance
		if special_state.request_special(special, use_ex):
			special_cooldown_timer = special_cooldown
			cooldown_timer = attack_cooldown
			was_attacking = true
			cancel_approach()
			if debug_specials:
				print(name, ": special started: ", special.resource_path, " EX=", use_ex)
			return true
		# EX may be unavailable because of insufficient meter.
		if use_ex and special_state.request_special(special, false):
			special_cooldown_timer = special_cooldown
			cooldown_timer = attack_cooldown
			was_attacking = true
			cancel_approach()
			if debug_specials:
				print(name, ": normal special started: ", special.resource_path)
			return true
	return false
#endregion

#region Attack Decision
func try_start_attack() -> void:
	if attack_state == null:
		find_attack_state()
	if attack_state == null or cooldown_timer > 0.0 or recovery_timer > 0.0 or is_defending():
		return
	if not enemy.is_on_floor() or not is_instance_valid(enemy.opponent):
		return
	var distance: float = absf(enemy.opponent.global_position.x - enemy.global_position.x)
	if distance > attack_range or randf() * 100.0 > attack_chance:
		return
	pending_attack_type = &"heavy" if randf() * 100.0 < heavy_chance else &"light"
	is_approaching_attack = true
	approach_timer = 0.0
	update_attack_approach(0.0)

func update_attack_approach(delta: float) -> void:
	if is_defending() or recovery_timer > 0.0 or not is_instance_valid(enemy.opponent) or not enemy.is_on_floor():
		cancel_approach()
		return
	approach_timer += delta
	var difference: float = enemy.opponent.global_position.x - enemy.global_position.x
	var distance: float = absf(difference)
	if distance > attack_range:
		cancel_approach()
		return
	if distance <= attack_approach_distance:
		enemy.stop_movement()
		is_approaching_attack = false
		if attack_state.request_attack(pending_attack_type):
			cooldown_timer = attack_cooldown
			last_combo_attack = null
			combo_decision_made = false
			was_attacking = true
		else:
			cooldown_timer = minf(attack_cooldown, 0.25)
		return
	if approach_timer >= approach_timeout:
		cancel_approach()
		cooldown_timer = attack_cooldown
		return
	enemy.set_movement_direction(signf(difference))

func cancel_approach() -> void:
	is_approaching_attack = false
	approach_timer = 0.0
#endregion

#region Combo Decision
func update_combo_decision() -> void:
	if attack_state == null or enemy.fsm == null or enemy.fsm.current_state != attack_state:
		return
	var current: AttackData = attack_state.current_attack
	if current == null:
		return
	if current != last_combo_attack:
		last_combo_attack = current
		combo_decision_made = false
	if combo_decision_made or not attack_state.hit_confirmed or not attack_state.is_inside_cancel_window():
		return
	combo_decision_made = true
	if randf() * 100.0 > combo_chance:
		return
	var next_type: StringName = choose_combo_attack(current)
	if next_type != &"":
		attack_state.request_combo(next_type)
#endregion

#region Combo Selection
func choose_combo_attack(current: AttackData) -> StringName:
	var has_light: bool = current.next_light_attack != null
	var has_heavy: bool = current.next_heavy_attack != null
	if has_light and has_heavy:
		return &"heavy" if randf() * 100.0 < heavy_chance else &"light"
	if has_light:
		return &"light"
	if has_heavy:
		return &"heavy"
	return &""
#endregion
