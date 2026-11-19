extends SceneTree
## Isolated integration fixtures for pause, buffs, encounter events and reload.
## Damage/position fixtures here are not a claimed full player campaign run.
var checks: int=0
var failures: int=0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _frames(n: int=5) -> void:
	for i: int in range(n):
		await physics_frame
		await process_frame

func _run() -> void:
	var save := ConfigFile.new()
	save.set_value("campaign","chapter",1)
	save.save("user://campaign.cfg")
	var game: Node=load("res://scenes/waterfront_game.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await _frames()
	_check(paused and game.menu.mode=="main" and game.enemies.size()==2,"Campaign starts paused with actual first encounter")
	game.menu.resume_game()
	for item in ["v20","v30","v20","weed"]:
		game._use_item(item)
		_check(game.player.state==&"use_item","Item starts an exclusive hand gesture: "+item)
		var count: int=game.inventory[item]
		game._use_item(item)
		_check(game.inventory[item]==count,"Repeated input cannot consume during an item gesture")
		await _frames(66)
	game.menu.show_pause()
	_check(game.buffs.power==30.0 and game.inventory.v20==0 and game.inventory.v30==0,"Stronger power replaces weaker power without stacking or downgrading")
	var timer: float=game.buffs.power_time
	var weed_timer: float=game.buffs.weed
	await _frames(12)
	_check(game.buffs.power_time==timer and game.buffs.weed==weed_timer,"Paused menus freeze real buff timers")
	var shawarma: int=game.inventory.shawarma
	game._use_item("shawarma")
	_check(game.inventory.shawarma==shawarma,"Full-health shawarma does not consume inventory")
	game.menu.resume_game()
	await _frames(8)
	_check(game.buffs.power_time<timer and game.player.damage_bonus==30.0 and game.player.damage_multiplier==1.25,"Resuming advances timers and applies combined buff values")
	_check(game.enemies[0].ai_time_scale==.42,"Weed reaches real enemy actor clocks")
	game.menu.show_pause()
	await _frames(4)
	timer=game.buffs.power_time
	await _frames(8)
	_check(game.buffs.power_time==timer,"Pause after gameplay freezes active buffs")
	# Synthetic fatal damage exercises actual knockout events, not health writes.
	for enemy: Node in game.enemies:
		enemy.receive_hit(enemy.health,game.player,&"environment",true)
	_check(game.phase==2 and game.total_defeated==2,"Last actual knockout unlocks route phase exactly once")
	game.player.position=Vector3(3,.1,-22)
	game.menu.resume_game()
	await _frames(3)
	_check(game.phase==3 and game.enemies.size()==4,"Crossing the second encounter threshold spawns the next wave")
	game.menu.show_result(false)
	var old_id: int=game.get_instance_id()
	var retry: Button=game.menu.box.find_children("*","Button",true,false)[0]
	retry.pressed.emit()
	await _frames(6)
	game=current_scene
	_check(game.get_instance_id()!=old_id and game.chapter==1 and paused and game.menu.mode=="main","Defeat Retry reloads a live chapter and restores its main menu")
	_check(game.player.health==160 and game.enemies.size()==2 and game.phase==1,"Retry resets health, encounter and transient campaign state")
	game.menu.show_result(true,false)
	var next: Button=game.menu.box.find_children("*","Button",true,false)[0]
	next.pressed.emit()
	await _frames(6)
	game=current_scene
	_check(game.chapter==2 and game.world.has_node("Spawn") and game.world.chapter==2,"Next loads the forest chapter through the saved campaign path")
	_check(game.player.global_position.distance_to(game.world.get_node("Spawn").global_position)<.5,"Forest player uses the actual Spawn marker")
	game.menu.show_result(true,false)
	next=game.menu.box.find_children("*","Button",true,false)[0]
	next.pressed.emit()
	await _frames(6)
	game=current_scene
	_check(game.chapter==3 and game.world.chapter==3,"Next loads the industrial chapter")
	for enemy: Node in game.enemies:
		enemy.receive_hit(enemy.health,game.player,&"environment",true)
	game.player.position=Vector3(0,.1,-22)
	game.menu.resume_game()
	await _frames(3)
	_check(game.phase==3 and game.enemies.size()==3 and game.enemies[2].name=="Oz" and game.enemies[2].boss_armor,"Industrial final encounter spawns actual armored Oz after normal enemies")
	game.menu.show_pause()
	var buttons: Array=game.menu.box.find_children("*","Button",true,false)
	(buttons[-1] as Button).pressed.emit()
	await _frames(6)
	game=current_scene
	_check(game.chapter==1 and game.phase==1 and paused,"Pause Restart begins a fresh campaign without a stuck pause")
	game.menu.resume_game()
	await _frames(3)
	game.player.receive_hit(game.player.health,game.enemies[0],&"kick",true)
	_check(not paused and game._restarting and game.player.state==&"knockdown","Death allows actual knockdown to animate before the defeat pause")
	await _frames(80)
	_check(paused and game.menu.mode=="defeat","Defeat menu opens after the knockdown settles")
	var head: Vector3=game.player.bone_anchor("head")
	var pelvis: Vector3=game.player.bone_anchor("pelvis")
	_check(head.y-game.player.global_position.y<.8 and absf(head.y-pelvis.y)<.4,"Defeat freezes the actual skinned character in a downed pose")
	print("GAME_FLOW_TESTS checks=",checks," failures=",failures)
	paused=false
	quit(1 if failures>0 else 0)
