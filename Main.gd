extends Node2D
# Backstreet - Case #001 prototype (throwaway code)
# STAGE 1: player movement + mode toggle (Tab) + wolfdog tint

enum Mode { HUMAN, WOLFDOG }

var mode: int = Mode.HUMAN
var player: CharacterBody2D
var player_visual: ColorRect
var camera: Camera2D
var tint: CanvasModulate
var mode_label: Label

const HUMAN_SPEED := 200.0
const WOLFDOG_SPEED := 300.0  # 1.5x
const HUMAN_COLOR := Color(0.25, 0.5, 1.0)      # blue
const WOLFDOG_COLOR := Color(1.0, 0.55, 0.1)    # orange
const WOLFDOG_TINT := Color(0.35, 0.55, 0.55)   # dark teal darkening


func _ready() -> void:
	_build_world()
	_build_player()
	_build_ui()
	_apply_mode()


func _build_world() -> void:
	# simple ground so movement is perceptible
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.2)
	bg.size = Vector2(2000, 2000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	add_child(bg)

	# reference grid markers
	for x in range(-4, 5):
		for y in range(-4, 5):
			var dot := ColorRect.new()
			dot.color = Color(0.22, 0.23, 0.27)
			dot.size = Vector2(8, 8)
			dot.position = Vector2(x * 200 - 4, y * 200 - 4)
			dot.z_index = -9
			add_child(dot)

	# tint overlay (only shown in wolfdog mode)
	tint = CanvasModulate.new()
	tint.color = Color.WHITE
	add_child(tint)


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2.ZERO
	add_child(player)

	player_visual = ColorRect.new()
	player_visual.size = Vector2(28, 28)
	player_visual.position = Vector2(-14, -14)
	player.add_child(player_visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	player.add_child(shape)

	camera = Camera2D.new()
	player.add_child(camera)
	camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	mode_label = Label.new()
	mode_label.position = Vector2(16, 12)
	mode_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(mode_label)

	var help := Label.new()
	help.position = Vector2(16, 44)
	help.add_theme_font_size_override("font_size", 14)
	help.text = "WASD/방향키: 이동   Tab: 모드 전환"
	layer.add_child(help)


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := WOLFDOG_SPEED if mode == Mode.WOLFDOG else HUMAN_SPEED
	player.velocity = dir * speed
	player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mode"):
		mode = Mode.WOLFDOG if mode == Mode.HUMAN else Mode.HUMAN
		_apply_mode()


func _apply_mode() -> void:
	if mode == Mode.WOLFDOG:
		player_visual.color = WOLFDOG_COLOR
		tint.color = WOLFDOG_TINT
		mode_label.text = "모드: 늑대개 (속도 1.5x)"
	else:
		player_visual.color = HUMAN_COLOR
		tint.color = Color.WHITE
		mode_label.text = "모드: 인간"
