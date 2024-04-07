extends Node3D

var SPEED := 40.0
var DAMAGE := 20
var velocity: Vector3
var collision_bool := true

var max_bounces := 0
var flip_scale := 1
@onready var mesh = $MeshInstance3D
@onready var ray = $RayCast3D

var object_scene := preload("res://scenes/collision_effects.tscn")
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var instance


# Called when the node enters the scene tree for the first time.
func _ready():
	ray.target_position.z = -0.05 * SPEED
	velocity = self.transform.basis.z * SPEED

	#var k = Vector3( randi_range(10,100),  randi_range(10,100),  randi_range(10,100))
	#self.look_at(global_transform.origin - velocity, Vector3.UP)


# Called every frame. 'delta' is the elapsed time since the previous frame.


func _process(delta):
	#move the bullet
	velocity.y += gravity * delta * flip_scale  # * -10

	self.transform.origin -= velocity * delta
	self.look_at(global_transform.origin - velocity, Vector3.UP)
	ray.force_raycast_update()
	if ray.is_colliding() and collision_bool:
		flip_scale *= 1  #-1 for fun
		collision_bool = false
		#get proper position
		self.global_transform.origin = ray.get_collision_point()
		#spawn hit balls  make spark
		instance = object_scene.instantiate()
		instance.position = ray.get_collision_point()
		instance.transform.basis = ray.global_transform.basis
		get_parent().add_child(instance)

		if ray.get_collider().is_in_group("player"):
			ray.get_collider().get_owner().hit(DAMAGE)

		if max_bounces != 0:
			#bounce
			var norm = ray.get_collision_normal().normalized()
			if norm:
				velocity = velocity.bounce(norm)
			max_bounces -= 1
		else:
			#kill bulet
			queue_free()
		collision_bool = true


func _on_timer_timeout():
	queue_free()
