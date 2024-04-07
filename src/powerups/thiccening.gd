extends Control


@rpc("call_local","any_peer") func execute(player):
	player.HEALTH_MAX += 50
	#player.transform.scaled(Vector3(0.1,0.1,0.1))
