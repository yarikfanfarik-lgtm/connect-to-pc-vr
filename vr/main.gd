extends Node3D

var screen: MeshInstance3D
var texture: ImageTexture
var ip_edit: LineEdit
var status: Label
var panel: Control

func _ready():
    var xr := XRServer.find_interface("OpenXR")
    if xr and xr.initialize():
        get_viewport().use_xr = true
    _build_scene()
    Network.frame_ready.connect(_on_frame)

func _build_scene():
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.015, 0.015, 0.02)
    env.environment = environment
    add_child(env)

    var cam := Camera3D.new()
    cam.position = Vector3(0, 0, 0.2)
    add_child(cam)
    cam.current = true

    var mesh := QuadMesh.new()
    mesh.size = Vector2(2.4, 1.35)
    screen = MeshInstance3D.new()
    screen.mesh = mesh
    screen.position = Vector3(0, 0, -2.0)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color.WHITE
    screen.material_override = mat
    add_child(screen)

    panel = Control.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)
    var box := VBoxContainer.new()
    box.position = Vector2(40, 40)
    box.size = Vector2(360, 180)
    panel.add_child(box)
    var title := Label.new()
    title.text = "CONNECT TO PC VR"
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "PC IP, e.g. 192.168.1.20"
    ip_edit.text = "192.168.1.20"
    box.add_child(ip_edit)
    var connect := Button.new()
    connect.text = "CONNECT"
    connect.pressed.connect(_connect)
    box.add_child(connect)
    status = Label.new()
    status.text = "Enter the PC IP address"
    box.add_child(status)

func _connect():
    status.text = Network.connect_to_pc(ip_edit.text.strip_edges())
    panel.visible = false

func _on_frame(image: Image):
    if texture == null:
        texture = ImageTexture.create_from_image(image)
        screen.material_override.albedo_texture = texture
    else:
        texture.update(image)
