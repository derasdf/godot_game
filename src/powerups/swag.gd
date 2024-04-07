extends Control

@rpc("call_local","any_peer") func execute(player):
	player.shoot_speed /= 2
	player.max_bounces += 1
	player.bullet_DAMAGE /= 2
	player.bullet_spread *= 16
