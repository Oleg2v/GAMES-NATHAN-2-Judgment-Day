extends Node3D
## Small authored props attached to the solved hand, with no collision body.
var actor: NathanCharacterController
var kind := ""

func _ready() -> void:
	if kind == "shawarma":
		_part(0.045,0.19,Color(0.78,0.61,0.35),0)
		_part(0.047,0.09,Color(0.91,0.89,0.80),-0.045)
		_part(0.036,0.014,Color(0.31,0.42,0.18),0.10)
	elif kind == "weed":
		_part(0.008,0.10,Color(0.88,0.85,0.69),0)
		_part(0.009,0.009,Color(0.77,0.36,0.14),0.051)
	else:
		_part(0.016,0.14,Color(0.84,0.88,0.86),0)
		_part(0.018,0.07,Color(0.87,0.36,0.57) if kind=="ozempic" else Color(0.31,0.64,0.69),-0.02)
		_part(0.010,0.035,Color(0.27,0.30,0.31),0.08)

func _part(radius: float, height: float, color: Color, y: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=12
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.72
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=material
	instance.position.y=y
	add_child(instance)

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or actor.state != &"use_item":
		queue_free()
		return
	global_position=actor.bone_anchor("hand_r")+actor.global_basis.z*0.045
	global_basis=actor.global_basis*Basis(Vector3.RIGHT,0.7 if kind in ["weed","shawarma"] else 1.3)
