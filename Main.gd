extends Node2D
# Backstreet - Case #001 prototype (throwaway code)
# STAGE 1: player movement + mode toggle (Tab) + wolfdog tint
# STAGE 2: map (4 zones) + interaction + clue system (toast + J panel)

enum Mode { HUMAN, WOLFDOG }

var mode: int = Mode.HUMAN
var player: CharacterBody2D
var player_visual: ColorRect
var camera: Camera2D
var tint: CanvasModulate
var mode_label: Label
var prompt_label: Label
var toast_label: Label
var clue_panel: Panel
var clue_vbox: VBoxContainer

var clues: Dictionary = {}          # id -> text
var interactables: Array = []       # array of dicts
var current_target = null

const HUMAN_SPEED := 200.0
const WOLFDOG_SPEED := 300.0  # 1.5x
const HUMAN_COLOR := Color(0.25, 0.5, 1.0)      # blue
const WOLFDOG_COLOR := Color(1.0, 0.55, 0.1)    # orange
const WOLFDOG_TINT := Color(0.35, 0.55, 0.55)   # dark teal darkening
const INTERACT_RADIUS := 62.0


func _ready() -> void:
	_build_world()
	_build_map()
	_build_player()
	_build_ui()
	_apply_mode()


func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14)
	bg.size = Vector2(3000, 3000)
	bg.position = Vector2(-1500, -1500)
	bg.z_index = -10
	add_child(bg)

	tint = CanvasModulate.new()
	tint.color = Color.WHITE
	add_child(tint)


# ---------------- MAP ----------------

func _add_zone(pos: Vector2, size: Vector2, color: Color, title: String) -> void:
	var floor_rect := ColorRect.new()
	floor_rect.color = color
	floor_rect.size = size
	floor_rect.position = pos
	floor_rect.z_index = -8
	add_child(floor_rect)

	var lbl := Label.new()
	lbl.text = title
	lbl.position = pos + Vector2(10, 8)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	lbl.z_index = -7
	add_child(lbl)


func _build_map() -> void:
	# 1) 편의점 내부 (top-left)
	_add_zone(Vector2(-520, -420), Vector2(500, 360), Color(0.22, 0.28, 0.30), "편의점 내부")
	# 2) 편의점 뒤 골목 (bottom-left)
	_add_zone(Vector2(-520, -20), Vector2(500, 340), Color(0.15, 0.18, 0.20), "편의점 뒤 골목")
	# 3) 옆 가게 앞 (top-right)
	_add_zone(Vector2(60, -420), Vector2(460, 360), Color(0.28, 0.25, 0.20), "옆 가게 앞")
	# 4) 막다른 골목 (bottom-right)
	_add_zone(Vector2(60, -20), Vector2(460, 340), Color(0.10, 0.11, 0.13), "막다른 골목 (뒷골목 입구)")

	# interactables ------------------------------------------------
	# 알바생 NPC (편의점) - dialogue is stage 3, placeholder for now
	_add_interactable(Vector2(-440, -320), Color(0.4, 0.8, 0.5), "알바생",
		"npc", true, _on_alba)
	# 조사: 폐기 선반의 긁힌 자국
	_add_interactable(Vector2(-120, -380), Color(0.6, 0.6, 0.65), "폐기 선반",
		"investigate", false, _on_shelf)
	# 조사: CCTV 모니터
	_add_interactable(Vector2(-460, -380), Color(0.5, 0.55, 0.7), "CCTV 모니터",
		"investigate", false, _on_cctv)
	# 할머니 NPC (옆 가게) - dialogue stage 3, placeholder
	_add_interactable(Vector2(300, -300), Color(0.85, 0.6, 0.75), "할머니",
		"npc", true, _on_granny)


func _add_interactable(pos: Vector2, color: Color, name: String, type: String,
		human_only: bool, handler: Callable) -> void:
	var visual := ColorRect.new()
	visual.color = color
	visual.size = Vector2(30, 30)
	visual.position = pos - Vector2(15, 15)
	add_child(visual)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.position = pos + Vector2(-30, -42)
	name_lbl.add_theme_font_size_override("font_size", 13)
	add_child(name_lbl)

	interactables.append({
		"pos": pos, "name": name, "type": type,
		"human_only": human_only, "handler": handler, "visual": visual,
	})


# ---------------- PLAYER ----------------

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(-270, -240)  # start inside convenience store
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


# ---------------- UI ----------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	mode_label = Label.new()
	mode_label.position = Vector2(16, 12)
	mode_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(mode_label)

	var help := Label.new()
	help.position = Vector2(16, 44)
	help.add_theme_font_size_override("font_size", 13)
	help.text = "WASD/방향키: 이동   Tab: 모드 전환   Space: 상호작용   J: 단서 목록"
	layer.add_child(help)

	# interaction prompt (bottom-center)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.size = Vector2(960, 30)
	prompt_label.position = Vector2(0, 470)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	prompt_label.text = ""
	layer.add_child(prompt_label)

	# toast (top-center)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.size = Vector2(960, 30)
	toast_label.position = Vector2(0, 90)
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color(0.6, 1, 0.7))
	toast_label.modulate.a = 0.0
	layer.add_child(toast_label)

	# clue panel (toggle J)
	clue_panel = Panel.new()
	clue_panel.size = Vector2(320, 260)
	clue_panel.position = Vector2(624, 76)
	clue_panel.visible = false
	layer.add_child(clue_panel)

	var title := Label.new()
	title.text = "── 단서 목록 ──"
	title.position = Vector2(14, 10)
	title.add_theme_font_size_override("font_size", 16)
	clue_panel.add_child(title)

	clue_vbox = VBoxContainer.new()
	clue_vbox.position = Vector2(14, 40)
	clue_vbox.size = Vector2(292, 210)
	clue_panel.add_child(clue_vbox)
	_refresh_clue_panel()


func _refresh_clue_panel() -> void:
	for c in clue_vbox.get_children():
		c.queue_free()
	if clues.is_empty():
		var empty := Label.new()
		empty.text = "(아직 없음)"
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		clue_vbox.add_child(empty)
		return
	for id in clues:
		var l := Label.new()
		l.text = "• " + clues[id]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(292, 0)
		clue_vbox.add_child(l)


func add_clue(id: String, text: String) -> void:
	if clues.has(id):
		show_toast("이미 확보한 단서")
		return
	clues[id] = text
	show_toast("단서 획득: " + text)
	_refresh_clue_panel()


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(toast_label, "modulate:a", 0.0, 1.0)


# ---------------- INTERACTION HANDLERS ----------------

func _on_alba() -> void:
	show_toast("알바생: 어서오세요~ (대화는 3단계에서)")

func _on_granny() -> void:
	show_toast("할머니: 응? (대화는 3단계에서)")

func _on_shelf() -> void:
	add_clue("scratch", "작은 손톱 긁힌 자국")

func _on_cctv() -> void:
	add_clue("cctv", "CCTV: 새벽 2시경 화면 노이즈, 인물 미검출")


# ---------------- LOOP ----------------

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := WOLFDOG_SPEED if mode == Mode.WOLFDOG else HUMAN_SPEED
	player.velocity = dir * speed
	player.move_and_slide()


func _process(_delta: float) -> void:
	_update_target()


func _update_target() -> void:
	current_target = null
	var best := INTERACT_RADIUS
	for it in interactables:
		# NPCs cannot be talked to in wolfdog mode
		if it["human_only"] and mode == Mode.WOLFDOG:
			continue
		var d: float = player.position.distance_to(it["pos"])
		if d < best:
			best = d
			current_target = it
	if current_target == null:
		prompt_label.text = ""
	else:
		var verb := "대화" if current_target["type"] == "npc" else "조사"
		prompt_label.text = "[Space] %s %s" % [current_target["name"], verb]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mode"):
		mode = Mode.WOLFDOG if mode == Mode.HUMAN else Mode.HUMAN
		_apply_mode()
	elif event.is_action_pressed("toggle_clues"):
		clue_panel.visible = not clue_panel.visible
	elif event.is_action_pressed("interact"):
		if current_target != null:
			current_target["handler"].call()


func _apply_mode() -> void:
	if mode == Mode.WOLFDOG:
		player_visual.color = WOLFDOG_COLOR
		tint.color = WOLFDOG_TINT
		mode_label.text = "모드: 늑대개 (속도 1.5x)"
	else:
		player_visual.color = HUMAN_COLOR
		tint.color = Color.WHITE
		mode_label.text = "모드: 인간"
