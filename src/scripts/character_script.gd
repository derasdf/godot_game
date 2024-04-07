extends CharacterBody3D

signal health_changed(health_value)
signal block_emit(time_persent)
signal reloading_emit(reloading_time)


@onready var camera_mount = $camera_mount
@onready var camera_3d = $camera_mount/Camera3D
@onready var animation_player = $visuals/character/AnimationPlayer
@onready var visuals = $visuals
@onready var gun_anim = $camera_mount/Camera3D/gun/gun_animation
@onready var gun_barrel = $camera_mount/Camera3D/gun/RayCast3D
@onready var character = $visuals/character
@onready var animation_tree = $visuals/character/AnimationTree
@onready var head = $visuals/character/Armature/Skeleton3D/head
@onready var Name = $visuals/Name

@onready var block = $block
@onready var block_collision = $block/block_collision

var block_reset := 3
@onready var block_cooldown = $block_cooldown

var shoot_speed := 0.1
@onready var attac_cooldown = $attac_cooldown

var reloading_time := 2
@onready var reloading_timer = $reloading_time


var angular_acc := 7
#bullets
var bullet = preload("res://scenes/bullet.tscn")

var SPEED := 3.0
const JUMP_VELOCITY := 4.5
var HEALTH_MAX := 100
var HEALTH := 100
var bullets_per_shot := 1
var bullet_spread := PI / 64
var ammo_mag_max := 6
var ammo_mag := 6

#bullet stuff
var bullet_SPEED := 40.0
var bullet_DAMAGE := 20
var max_bounces := 0
var flip_scale := 1

var ground_control := 3.0
var walking_speed := 5.0
var running_speed := 8.0
var running := false
var shitting := false
var sliding := false
var is_dead := false
signal player_hit

@export var sensitivity_horizontal := 0.5
@export var sensitivity_vertical := 0.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	Name.text = str(name)
	if not is_multiplayer_authority():
		return

	animation_tree.active = true
	#health_left.text =  str(HEALTH)
	#HEALTH = HEALTH_	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_3d.current = true


func _input(event):
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sensitivity_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sensitivity_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sensitivity_vertical))
		camera_mount.rotation_degrees.x = clamp(camera_mount.rotation_degrees.x, -70, 90)


func _physics_process(delta):

	if not is_multiplayer_authority():
		return
	if is_dead:
		return
	if Input.is_action_pressed("kill_urself"):
		HEALTH = -1
	if Input.is_action_pressed("run") and Input.is_action_just_pressed("crouch") and !sliding:
		running = false
		shitting = true
		sliding = true
	else:
		if Input.is_action_pressed("crouch"):
			SPEED = lerp(SPEED, walking_speed / 4, delta )
			shitting = true
		else:
			SPEED = lerp(SPEED, walking_speed, delta * ground_control)
			shitting = false
					#running
			if Input.is_action_pressed("run"):
				SPEED = lerp(SPEED, running_speed, delta * ground_control)
				running = true
			else:
				SPEED = lerp(SPEED, walking_speed, delta * ground_control)
				running = false

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animation_tree.set("parameters/jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			if sliding:
				animation_tree.set(
					"parameters/runtoslide/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
				)
				sliding = false
			elif shitting:
				animation_tree.set("parameters/cw_trans/transition_request", "sittin")
				animation_tree.set(
					"parameters/sneakIdle_blend/blend_amount",
					lerp(
						animation_tree.get("parameters/sneakIdle_blend/blend_amount"),
						0.63,
						delta * ground_control
					)
				)
			elif running:
				if animation_tree.get("parameters/cw_trans/current_state") != "running":
					animation_tree.set("parameters/cw_trans/transition_request", "walkin")
					#animation_tree.set("parameters/iwr_blend/blend_amount",lerp(animation_tree.get("parameters/iwr_blend/blend_amount"),1.0,delta * ground_control))
					ground_control = 5.0
			else:
				if animation_tree.get("parameters/cw_trans/current_state") != "walking":
					animation_tree.set("parameters/cw_trans/transition_request", "walkin")
					#animation_tree.set("parameters/iwr_blend/blend_amount",lerp(animation_tree.get("parameters/iwr_blend/blend_amount"),0.0,delta * ground_control))
			

			#visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(-direction.x, -direction.z), delta * 5.0)
			#character.rotation.y = lerp_angle(character.rotation.y,atan2(direction.x, direction.z), delta * angular_acc)
			visuals.look_at(position + direction)
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			ground_control = 3.0

		else:
			if animation_player.current_animation != "idle" and !shitting:
				animation_tree.set("parameters/cw_trans/transition_request", "walkin")
				#animation_tree.set("parameters/iwr_blend/blend_amount",lerp(animation_tree.get("parameters/iwr_blend/blend_amount"),-1.0,delta * ground_control))
			elif animation_player.current_animation != "sneak idle" and shitting:
				animation_tree.set("parameters/cw_trans/transition_request", "sittin")
				animation_tree.set(
					"parameters/sneakIdle_blend/blend_amount",
					lerp(
						animation_tree.get("parameters/sneakIdle_blend/blend_amount"),
						0.0,
						delta * ground_control
					)
				)
			velocity.x = lerp(velocity.x, direction.x * SPEED, delta * ground_control)
			velocity.z = lerp(velocity.z, direction.z * SPEED, delta * ground_control)
	else:
		if direction:
			visuals.look_at(position + direction)
		var air_control := 6.0
		velocity.x = lerp(velocity.x, direction.x * SPEED, delta * air_control)
		velocity.z = lerp(velocity.z, direction.z * SPEED, delta * air_control)

	if Input.is_action_just_pressed("reload")	and reloading_timer.is_stopped():
		reloading_timer.start(reloading_time)
		await reloading_timer.timeout
		ammo_mag = ammo_mag_max
	if !reloading_timer.is_stopped():
		reloading_emit.emit((reloading_timer.time_left/reloading_timer.wait_time)*100)
	else:
		reloading_emit.emit(0)		

	if Input.is_action_just_pressed("block") and block_cooldown.is_stopped():
		block_func.rpc()
		
	if !block_cooldown.is_stopped():
		block_emit.emit((block_cooldown.time_left/block_cooldown.wait_time)*100)
	else:
		block_emit.emit(0)		

	#shoot animation
	#if Input.is_action_pressed("shoot"):
	if Input.is_action_just_pressed("shoot") and attac_cooldown.is_stopped() and ammo_mag > 0 and reloading_timer.is_stopped():
		#shoot_animation.rpc()
		attac_cooldown.start(shoot_speed)
		ammo_mag -= 1
		for sex in bullets_per_shot:
			spawn_bulet.rpc()

	var iw_blend = (velocity.length() - walking_speed) / walking_speed
	var wr_blend = (velocity.length() - walking_speed) / (running_speed - walking_speed)

	if velocity.length() <= walking_speed:
		animation_tree.set("parameters/iwr_blend/blend_amount", iw_blend)
	else:
		animation_tree.set("parameters/iwr_blend/blend_amount", wr_blend)

	if Input.is_action_just_released("gangnam"):
		if animation_tree.get("parameters/gangnam/active"):
			animation_tree["parameters/gangnam/request"] = (
				AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
			)
		else:
			animation_tree.set(
				"parameters/gangnam/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
			)
	if Input.is_action_just_released("salsa"):
		if animation_tree.get("parameters/salsa/active"):
			animation_tree["parameters/salsa/request"] = (
				AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
			)
		else:
			animation_tree["parameters/salsa/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	#velocity = lerp(velocity,direction * SPEED,delta * 3.0)
	move_and_slide()

@rpc("call_local") func block_func():
	block.visible = true
	block_collision.disabled = false
	await get_tree().create_timer(2).timeout
	block.visible = false
	block_collision.disabled = true	
	block_cooldown.start(block_reset)

@rpc("call_local") func shoot_animation():
	if not is_multiplayer_authority():
		return
	if !gun_anim.is_playing():
		gun_anim.play("Shoot")


@rpc("call_local", "any_peer", "reliable") func spawn_bulet():
	var instance = bullet.instantiate()

	instance.SPEED = bullet_SPEED
	instance.DAMAGE =  bullet_DAMAGE
	instance.max_bounces = max_bounces
	instance.flip_scale = flip_scale
	
	instance.name = str(multiplayer.get_unique_id())
	instance.position = gun_barrel.global_transform.origin
	instance.transform.basis = gun_barrel.global_transform.basis


	var rotation_axis = (
		Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	)
	var rotation_angle = randf_range(0.0, bullet_spread)
	instance.transform.basis = instance.transform.basis.rotated(rotation_axis, rotation_angle)
	#instance.SPEED = 2.0
	get_parent().add_child(instance, true)


@rpc("any_peer") func hit(Damage_recieved):
	if not is_multiplayer_authority():
		return
	HEALTH -= Damage_recieved

	if HEALTH <= 0:
		#HEALTH = 100
		#position = Vector3.ZERO
		is_dead = true
	health_changed.emit(HEALTH)


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Shoot":
		animation_player.play("idle")
