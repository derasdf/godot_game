extends Control

@rpc("call_local","any_peer") func execute(player):
	player.HEALTH_MAX -= 10
	player.bullet_DAMAGE += 10
	
