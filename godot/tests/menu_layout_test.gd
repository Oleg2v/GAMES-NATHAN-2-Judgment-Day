extends SceneTree
const Menu = preload("res://scripts/game_menu.gd")

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var menu := Menu.new()
	root.add_child(menu)
	await create_timer(0.20,true).timeout
	var errors: Array[String] = []
	var cases := 0
	for css in [Vector2(667,375),Vector2(844,390),Vector2(1280,800)]:
		var viewport_size := Vector2(css.x/css.y*800.0,800.0)
		for language in ["ru","en","he"]:
			menu.language=language
			for mode in ["main","help","settings","bag","pause","result"]:
				menu.mode=""
				match mode:
					"main":menu.show_main()
					"help":menu.show_help()
					"settings":menu.show_settings()
					"bag":menu.show_bagfull({"v20":2,"v30":1,"weed":0,"ozempic":1,"shawarma":3})
					"pause":menu.show_pause()
					"result":menu.show_result(true)
				menu._layout_for_metrics(viewport_size,css)
				await process_frame
				await process_frame
				var id := "%dx%d %s %s"%[css.x,css.y,language,mode]
				var end: Vector2=menu._panel.position+menu._panel.size*menu._ui_scale
				if end.x>viewport_size.x+1 or end.y>viewport_size.y+1:
					errors.append(id+" panel overflow "+str(end))
				if menu._panel.size.x>minf(410.0,maxf(298.0,css.x*0.46))+1:
					errors.append(id+" width expanded "+str(menu._panel.size.x))
				for node in menu.box.find_children("*","Button",true,false):
					if node.size.y<43.9:
						errors.append(id+" target below44: "+str(node.size.y))
					var bounds: Rect2=node.get_global_rect().grow(1.0)
					for label in node.find_children("*","Label",true,false):
						if not bounds.encloses(label.get_global_rect()):
							errors.append(id+" card text overflow: "+label.text)
				if menu.box.size.x>menu._scroll.size.x+1:
					errors.append(id+" horizontal content overflow")
				if mode=="bag":
					for key in ["v20","v30","weed","ozempic","shawarma"]:
						if menu.box.get_node_or_null("Item_"+key)==null:errors.append(id+" item missing "+key)
				# Overflow is intentional only vertically: the final action must
				# remain fully reachable through the real ScrollContainer.
				var last: Control=menu.box.get_child(menu.box.get_child_count()-1)
				menu._scroll.ensure_control_visible(last)
				await process_frame
				await process_frame
				if not menu._scroll.get_global_rect().grow(1.0).encloses(last.get_global_rect()):
					errors.append(id+" final action clipped after scrolling")
				cases+=1
	print(JSON.stringify({"cases":cases,"errors":errors,"minimum_target_css":44,"left_width_desktop_css":410,"mobile_width_css":306.82}))
	paused=false
	quit(0 if errors.is_empty() else 1)
