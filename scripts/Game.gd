extends Node2D
## Ash of the Seven Kingdoms — a self-contained, hand-crafted playable prologue.
## No commercial assets, network access, advertising SDK, or personal data collection.

const W: float = 1280.0
const H: float = 720.0
const GROUND: float = 592.0
const WORLD_END: float = 7580.0
const RUN_SPEED: float = 290.0
const GRAVITY: float = 1750.0
const JUMP_SPEED: float = -700.0
const MAX_HP: float = 100.0
const MAX_MANA: float = 100.0
const SAVE_PATH: String = "user://ash_save.json"
const GOLD = Color(1.0, 0.80, 0.46)
const CREAM = Color(1.0, 0.95, 0.84)
const VIOLET = Color(0.74, 0.46, 1.0)
const CYAN = Color(0.35, 0.91, 1.0)
const RED = Color(1.0, 0.34, 0.24)

const ZONE_NAMES = ["Храм пробуждения", "Изумрудная чаща", "Пепельный хутор", "Святилище Морвена"]
const QUESTS = [
    "Пробудись. Найди выход из разрушенного храма.",
    "Иди на восток через зачарованный лес.",
    "Пройди разорённый хутор к древнему святилищу.",
    "Победи Морвена — Хранителя шипов."
]
const EN_ZONE_NAMES = ["Temple of Awakening", "Emerald Wilds", "Ashen Hamlet", "Morwen's Sanctuary"]
const EN_QUESTS = [
    "Awaken. Find the temple's broken gate.",
    "Travel east through the enchanted forest.",
    "Cross the ruined hamlet to the sanctuary.",
    "Defeat Morwen, Keeper of Thorns."
]

@onready var backdrop: Texture2D = preload("res://art/emerald_forest.png")
@onready var music_player: AudioStreamPlayer = $Music
var sword_sound: AudioStream = preload("res://audio/sword.wav")
var magic_sound: AudioStream = preload("res://audio/magic.wav")
var hurt_sound: AudioStream = preload("res://audio/hurt.wav")
var victory_sound: AudioStream = preload("res://audio/victory.wav")
var ambience: AudioStream = preload("res://audio/ambience.wav")

var rng := RandomNumberGenerator.new()
var game_state: String = "title" # title, playing, paused, dead, choice, ending
var language: String = "ru"
var player: Vector2 = Vector2(170.0, GROUND)
var velocity_y: float = 0.0
var grounded: bool = true
var facing: int = 1
var moving: bool = false
var hp: float = MAX_HP
var mana: float = MAX_MANA
var souls: int = 0
var camera_x: float = 0.0
var world_time: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var cast_cooldown: float = 0.0
var hurt_timer: float = 0.0
var invulnerability: float = 0.0
var screen_shake: float = 0.0
var boss_hp: float = 260.0
var boss_alive: bool = true
var boss_attack_timer: float = 1.5
var boss_intro_done: bool = false
var soul_choice: String = ""
var checkpoint_x: float = 170.0
var checkpoint_index: int = 0
var active_zone: int = 0
var message: String = ""
var message_timer: float = 0.0
var message_color: Color = CREAM
var wolves_killed: int = 0
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var touches: Dictionary = {} # touch index -> virtual button
var touch_controls: bool = false
var did_win: bool = false

func _ready() -> void:
    rng.randomize()
    _spawn_enemies()
    music_player.stream = ambience
    music_player.volume_db = -20.0
    music_player.finished.connect(_loop_music)
    music_player.play()
    show_message("Семь сердец. Семь проклятий. Одна забытая клятва.", 5.0)
    queue_redraw()

func _loop_music() -> void:
    music_player.play()

func tr_ru(ru: String, en: String) -> String:
    return ru if language == "ru" else en

func show_message(text: String, seconds: float = 4.0, color: Color = CREAM) -> void:
    message = text
    message_timer = seconds
    message_color = color

func play_sound(sound: AudioStream, volume: float = -9.0) -> void:
    var voice := AudioStreamPlayer.new()
    add_child(voice)
    voice.stream = sound
    voice.volume_db = volume
    voice.finished.connect(voice.queue_free)
    voice.play()

func _spawn_enemies() -> void:
    enemies.clear()
    for x in [690.0, 1190.0, 2030.0, 2480.0, 2920.0, 3670.0, 4560.0, 4860.0, 5320.0, 5800.0]:
        var foe_type := "wraith" if int(x) % 3 == 0 else "wolf"
        if x > 4500.0:
            foe_type = "cultist"
        enemies.append({"x": x, "y": GROUND, "hp": 55.0 if foe_type == "cultist" else 43.0, "max_hp": 55.0 if foe_type == "cultist" else 43.0, "type": foe_type, "cd": rng.randf_range(0.4, 1.8), "phase": rng.randf_range(0.0, TAU), "hurt": 0.0, "dir": -1})

func _reset_run(load_checkpoint: bool = false) -> void:
    game_state = "playing"
    boss_alive = true
    did_win = false
    boss_hp = 260.0
    boss_intro_done = false
    soul_choice = ""
    boss_attack_timer = 2.0
    hp = MAX_HP
    mana = MAX_MANA
    velocity_y = 0.0
    grounded = true
    attack_timer = 0.0
    attack_cooldown = 0.0
    cast_cooldown = 0.0
    projectiles.clear()
    motes.clear()
    souls = 0
    checkpoint_x = 170.0
    checkpoint_index = 0
    if load_checkpoint:
        _read_save()
    player = Vector2(checkpoint_x, GROUND)
    camera_x = clampf(player.x - 400.0, 0.0, WORLD_END - W)
    active_zone = _zone_at(player.x)
    _spawn_enemies()
    # Restore a cleared path leading up to a checkpoint.
    for e in enemies:
        if float(e["x"]) < checkpoint_x - 150.0:
            e["hp"] = 0.0
    show_message(tr_ru("Страж Пламени пробуждается...", "The Flamewarden awakens..."), 3.5, GOLD)

func _save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({"checkpoint": checkpoint_x, "souls": souls, "lang": language}))

func _read_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var data: Variant = JSON.parse_string(f.get_as_text())
    if data is Dictionary:
        checkpoint_x = clampf(float(data.get("checkpoint", 170.0)), 170.0, 6300.0)
        souls = maxi(0, int(data.get("souls", 0)))
        language = str(data.get("lang", "ru"))

func _zone_at(world_x: float) -> int:
    if world_x < 1800.0: return 0
    if world_x < 4380.0: return 1
    if world_x < 6280.0: return 2
    return 3

func _physics_process(delta: float) -> void:
    if game_state != "playing":
        return
    world_time += delta
    message_timer = maxf(0.0, message_timer - delta)
    attack_timer = maxf(0.0, attack_timer - delta)
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    cast_cooldown = maxf(0.0, cast_cooldown - delta)
    invulnerability = maxf(0.0, invulnerability - delta)
    hurt_timer = maxf(0.0, hurt_timer - delta)
    screen_shake = maxf(0.0, screen_shake - delta * 1.8)
    mana = minf(MAX_MANA, mana + delta * 7.5)
    var move_axis := 0.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or _button_down("left"):
        move_axis -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or _button_down("right"):
        move_axis += 1.0
    moving = absf(move_axis) > 0.01
    if moving:
        facing = 1 if move_axis > 0.0 else -1
        player.x = clampf(player.x + move_axis * RUN_SPEED * delta, 48.0, WORLD_END - 60.0)
    velocity_y += GRAVITY * delta
    player.y += velocity_y * delta
    if player.y >= GROUND:
        player.y = GROUND
        velocity_y = 0.0
        grounded = true
    else:
        grounded = false
    camera_x = lerpf(camera_x, clampf(player.x - W * 0.37, 0.0, WORLD_END - W), minf(1.0, delta * 4.2))
    _update_progress()
    _update_enemies(delta)
    _update_boss(delta)
    _update_projectiles(delta)
    _update_motes(delta)

func _process(delta: float) -> void:
    if game_state != "playing":
        world_time += delta * 0.35
    queue_redraw()

func _update_progress() -> void:
    var new_zone := _zone_at(player.x)
    if new_zone != active_zone:
        active_zone = new_zone
        if language == "ru":
            show_message("ГЛАВА %d — %s" % [new_zone + 1, ZONE_NAMES[new_zone]], 4.0, GOLD)
        else:
            show_message("CHAPTER %d — %s" % [new_zone + 1, EN_ZONE_NAMES[new_zone]], 4.0, GOLD)
    var cp := 0
    if player.x > 1830.0: cp = 1
    if player.x > 4400.0: cp = 2
    if player.x > 6300.0: cp = 3
    if cp > checkpoint_index:
        checkpoint_index = cp
        checkpoint_x = [170.0, 1860.0, 4440.0, 6330.0][cp]
        hp = minf(MAX_HP, hp + 32.0)
        mana = MAX_MANA
        _save()
        show_message(tr_ru("Открыто святилище. Прогресс сохранён!", "Sanctuary reached. Progress saved!"), 4.0, CYAN)
    if player.x > 6510.0 and not boss_intro_done:
        boss_intro_done = true
        screen_shake = 0.65
        show_message(tr_ru("МОРВЕН: Ты вернулся, Страж? Тогда умри ещё раз!", "MORWEN: You return, Warden? Then die again!"), 6.0, VIOLET)

func _button_down(button: String) -> bool:
    return touches.values().has(button)

func _jump() -> void:
    if game_state == "playing" and grounded:
        velocity_y = JUMP_SPEED
        grounded = false
        _burst(player + Vector2(0, -8), Color(0.75, 0.78, 0.65), 8, 100.0)

func _slash() -> void:
    if game_state != "playing" or attack_cooldown > 0.0:
        return
    attack_timer = 0.25
    attack_cooldown = 0.48
    play_sound(sword_sound, -9.0)
    var scored := false
    for e in enemies:
        if float(e["hp"]) <= 0.0:
            continue
        var dx := float(e["x"]) - player.x
        if absf(dx) < 105.0 and dx * facing >= -14.0 and absf(float(e["y"]) - player.y) < 84.0:
            _damage_enemy(e, 27.0)
            scored = true
    if boss_alive and boss_intro_done and absf(player.x - 7030.0) < 134.0 and (7030.0 - player.x) * facing >= -35.0:
        _damage_boss(19.0)
        scored = true
    _burst(player + Vector2(55.0 * facing, -82.0), GOLD if scored else CYAN, 8, 160.0)

func _cast() -> void:
    if game_state != "playing" or cast_cooldown > 0.0 or mana < 24.0:
        return
    mana -= 24.0
    cast_cooldown = 0.58
    play_sound(magic_sound, -10.0)
    _spawn_projectile(player.x + facing * 38.0, player.y - 88.0, facing * 610.0, -14.0, 34.0, "fire", false)
    _burst(player + Vector2(facing * 38.0, -88.0), Color(1.0, 0.49, 0.12), 16, 220.0)

func _damage_player(amount: float) -> void:
    if invulnerability > 0.0 or game_state != "playing":
        return
    hp = maxf(0.0, hp - amount)
    invulnerability = 0.85
    hurt_timer = 0.33
    screen_shake = 0.43
    play_sound(hurt_sound, -11.0)
    _burst(player + Vector2(0, -75), RED, 18, 180.0)
    if hp <= 0.0:
        game_state = "dead"
        touches.clear()
        show_message(tr_ru("Пепел помнит твоё имя...", "The ashes remember your name..."), 6.0)

func _damage_enemy(e: Dictionary, amount: float) -> void:
    e["hp"] = maxf(0.0, float(e["hp"]) - amount)
    e["hurt"] = 0.2
    _burst(Vector2(float(e["x"]), float(e["y"]) - 65.0), VIOLET, 10, 155.0)
    if float(e["hp"]) == 0.0:
        souls += 12
        _burst(Vector2(float(e["x"]), float(e["y"]) - 75.0), CYAN, 23, 215.0)
        if e["type"] == "wolf": wolves_killed += 1

func _damage_boss(amount: float) -> void:
    if not boss_alive:
        return
    boss_hp = maxf(0.0, boss_hp - amount)
    screen_shake = 0.22
    _burst(Vector2(7030.0, GROUND - 118.0), VIOLET, 16, 200.0)
    if boss_hp <= 0.0:
        boss_alive = false
        game_state = "choice"
        souls += 180
        screen_shake = 1.1
        play_sound(victory_sound, -2.0)
        _burst(Vector2(7030.0, GROUND - 110.0), GOLD, 90, 410.0)

func _spawn_projectile(x: float, y: float, vx: float, vy: float, damage: float, kind: String, hostile: bool) -> void:
    projectiles.append({"pos": Vector2(x, y), "v": Vector2(vx, vy), "damage": damage, "life": 3.5, "kind": kind, "hostile": hostile})

func _update_enemies(delta: float) -> void:
    for e in enemies:
        if float(e["hp"]) <= 0.0:
            continue
        e["cd"] = maxf(0.0, float(e["cd"]) - delta)
        e["hurt"] = maxf(0.0, float(e["hurt"]) - delta)
        e["phase"] = float(e["phase"]) + delta
        var distance := player.x - float(e["x"])
        e["dir"] = 1 if distance > 0.0 else -1
        if absf(distance) > 650.0:
            continue
        var typ: String = str(e["type"])
        if typ == "cultist":
            if absf(distance) < 150.0:
                e["x"] = float(e["x"]) - signf(distance) * 90.0 * delta
            if float(e["cd"]) <= 0.0 and absf(distance) < 510.0:
                var from := Vector2(float(e["x"]), GROUND - 110.0)
                var shot_direction := (player + Vector2(0.0, -85.0) - from).normalized()
                _spawn_projectile(from.x, from.y, shot_direction.x * 310.0, shot_direction.y * 310.0, 13.0, "shadow", true)
                e["cd"] = rng.randf_range(1.8, 2.9)
                _burst(from, VIOLET, 7, 100.0)
        else:
            if absf(distance) > 65.0:
                e["x"] = float(e["x"]) + signf(distance) * (185.0 if typ == "wolf" else 138.0) * delta
            elif float(e["cd"]) <= 0.0 and absf(player.y - GROUND) < 120.0:
                _damage_player(14.0 if typ == "wolf" else 10.0)
                e["cd"] = 1.25 if typ == "wolf" else 1.65

func _update_boss(delta: float) -> void:
    if not boss_alive or not boss_intro_done:
        return
    if absf(player.x - 7030.0) > 900.0:
        return
    boss_attack_timer -= delta
    if boss_attack_timer > 0.0:
        return
    var origin := Vector2(7030.0, GROUND - 120.0 + sin(world_time * 2.0) * 14.0)
    var aimed := (player + Vector2(0.0, -70.0) - origin).normalized()
    var phase := int(ceilf(boss_hp / 65.0))
    if phase % 2 == 0:
        for offset in [-0.23, 0.0, 0.23]:
            var a: Vector2 = aimed.rotated(float(offset))
            _spawn_projectile(origin.x, origin.y, a.x * 330.0, a.y * 330.0, 16.0, "thorn", true)
    else:
        for offset in [-0.13, 0.0, 0.13]:
            var a: Vector2 = aimed.rotated(float(offset))
            _spawn_projectile(origin.x, origin.y, a.x * 365.0, a.y * 365.0, 12.0, "shadow", true)
    boss_attack_timer = 1.8 if boss_hp > 130.0 else 1.2
    screen_shake = 0.13
    _burst(origin, VIOLET, 17, 195.0)

func _update_projectiles(delta: float) -> void:
    for i in range(projectiles.size() - 1, -1, -1):
        var p: Dictionary = projectiles[i]
        p["life"] = float(p["life"]) - delta
        p["pos"] = Vector2(p["pos"]) + Vector2(p["v"]) * delta
        var pos: Vector2 = p["pos"]
        if float(p["life"]) <= 0.0 or pos.y > H + 140.0:
            projectiles.remove_at(i)
            continue
        if bool(p["hostile"]):
            if pos.distance_to(player + Vector2(0, -68)) < 37.0:
                _damage_player(float(p["damage"]))
                _burst(pos, VIOLET, 10, 110.0)
                projectiles.remove_at(i)
        else:
            var hit := false
            for e in enemies:
                if float(e["hp"]) > 0.0 and pos.distance_to(Vector2(float(e["x"]), float(e["y"]) - 65.0)) < 52.0:
                    _damage_enemy(e, float(p["damage"]))
                    hit = true
                    break
            if not hit and boss_alive and boss_intro_done and pos.distance_to(Vector2(7030.0, GROUND - 125.0)) < 110.0:
                _damage_boss(float(p["damage"]))
                hit = true
            if hit:
                _burst(pos, Color(1.0, 0.62, 0.23), 18, 170.0)
                projectiles.remove_at(i)

func _burst(center: Vector2, tint: Color, count: int, speed: float) -> void:
    for i in count:
        var angle := rng.randf_range(-PI, PI)
        var magnitude := rng.randf_range(0.2, 1.0) * speed
        motes.append({"p": center, "v": Vector2(cos(angle), sin(angle)) * magnitude, "life": rng.randf_range(0.3, 0.9), "max": 0.9, "size": rng.randf_range(1.5, 5.0), "color": tint})
    if motes.size() > 320:
        motes = motes.slice(motes.size() - 320)

func _update_motes(delta: float) -> void:
    for i in range(motes.size() - 1, -1, -1):
        var p: Dictionary = motes[i]
        p["life"] = float(p["life"]) - delta
        if float(p["life"]) <= 0.0:
            motes.remove_at(i)
        else:
            p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
            p["v"] = Vector2(p["v"]) * (1.0 - 1.5 * delta) + Vector2(0.0, 40.0 * delta)

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key: InputEventKey = event
        if not key.pressed or key.echo:
            return
        if key.keycode == KEY_F1:
            language = "en" if language == "ru" else "ru"
            return
        if game_state == "title":
            if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
                _reset_run(FileAccess.file_exists(SAVE_PATH))
            return
        if game_state == "dead":
            if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
                _reset_run(true)
            return
        if game_state == "ending":
            if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
                _reset_run(false)
            return
        if game_state == "choice":
            if key.keycode == KEY_F:
                _choose_soul("free")
            if key.keycode == KEY_G:
                _choose_soul("take")
            return
        if key.keycode == KEY_ESCAPE or key.keycode == KEY_P:
            game_state = "paused" if game_state == "playing" else "playing"
            return
        if game_state != "playing":
            return
        match key.keycode:
            KEY_SPACE, KEY_W, KEY_UP: _jump()
            KEY_J, KEY_Z: _slash()
            KEY_K, KEY_X: _cast()
            KEY_E, KEY_F: _interact()
    elif event is InputEventScreenTouch:
        touch_controls = true
        var t: InputEventScreenTouch = event
        if t.pressed:
            var b := _tap(Vector2(t.position))
            if b != "":
                touches[t.index] = b
        else:
            touches.erase(t.index)
    elif event is InputEventScreenDrag:
        touch_controls = true
        var d: InputEventScreenDrag = event
        if touches.has(d.index) and (touches[d.index] == "left" or touches[d.index] == "right"):
            var new_button := _virtual_button(Vector2(d.position))
            if new_button == "left" or new_button == "right":
                touches[d.index] = new_button
    elif event is InputEventMouseButton:
        var m: InputEventMouseButton = event
        if m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
            _tap(Vector2(m.position))

func _virtual_button(p: Vector2) -> String:
    if p.y < 566.0:
        return ""
    if p.x >= 18.0 and p.x < 142.0:
        return "left"
    if p.x >= 145.0 and p.x < 273.0:
        return "right"
    if p.x >= 840.0 and p.x < 948.0:
        return "interact"
    if p.x >= 949.0 and p.x < 1055.0:
        return "slash"
    if p.x >= 1056.0 and p.x < 1167.0:
        return "cast"
    if p.x >= 1168.0:
        return "jump"
    return ""

func _tap(p: Vector2) -> String:
    if game_state == "title":
        if Rect2(425, 465, 430, 76).has_point(p):
            _reset_run(FileAccess.file_exists(SAVE_PATH))
        elif Rect2(1060, 36, 156, 62).has_point(p):
            language = "en" if language == "ru" else "ru"
        return ""
    if game_state == "dead":
        if Rect2(425, 460, 430, 90).has_point(p):
            _reset_run(true)
        return ""
    if game_state == "ending":
        if Rect2(425, 492, 430, 86).has_point(p):
            _reset_run(false)
        return ""
    if game_state == "choice":
        if Rect2(235, 440, 370, 100).has_point(p):
            _choose_soul("free")
        elif Rect2(676, 440, 370, 100).has_point(p):
            _choose_soul("take")
        return ""
    if game_state == "paused":
        game_state = "playing"
        return ""
    if game_state != "playing":
        return ""
    if Rect2(1183, 25, 65, 64).has_point(p):
        game_state = "paused"
        return ""
    var b := _virtual_button(p)
    match b:
        "slash": _slash()
        "cast": _cast()
        "jump": _jump()
        "interact": _interact()
    return b

func _interact() -> void:
    if game_state != "playing":
        return
    if player.x < 540.0:
        show_message(tr_ru("Надпись на камне: «Не верь тому, что помнит огонь».", "Inscription: 'Trust not what the fire remembers.'"), 5.0, GOLD)
    elif player.x > 4550.0 and player.x < 5150.0:
        hp = minf(MAX_HP, hp + 23.0)
        show_message(tr_ru("Старик: «Морвен боится света. Забери мою траву». +23 здоровья", "Elder: 'Morwen fears the light. Take these herbs.' +23 health"), 5.0, CYAN)
    elif absf(player.x - checkpoint_x) < 200.0:
        hp = minf(MAX_HP, hp + 30.0)
        mana = MAX_MANA
        _save()
        show_message(tr_ru("Пламя у алтаря согревает душу. Сохранено.", "The altar flame restores your spirit. Saved."), 4.0, GOLD)
    else:
        show_message(tr_ru("Тишина. Лишь пепел кружится в воздухе.", "Silence. Only ashes drift in the air."), 2.5)

func _choose_soul(what: String) -> void:
    if game_state != "choice":
        return
    soul_choice = what
    did_win = true
    game_state = "ending"
    if what == "free":
        show_message(tr_ru("Ты освободил первое драконье сердце.", "You freed the first dragon heart."), 4.0, CYAN)
    else:
        show_message(tr_ru("Ты присвоил силу древнего дракона.", "You claimed the ancient dragon's power."), 4.0, RED)

# -----------------------------------------------------------------------------
# RENDERING. Canvas drawing uses resolution-independent Godot viewport scaling.
# -----------------------------------------------------------------------------
func _draw() -> void:
    draw_rect(Rect2(0, 0, W, H), Color(0.014, 0.025, 0.04))
    _draw_background()
    _draw_world()
    _draw_effects()
    _draw_hud()
    if game_state == "title": _draw_title()
    elif game_state == "paused": _draw_paused()
    elif game_state == "dead": _draw_dead()
    elif game_state == "choice": _draw_choice()
    elif game_state == "ending": _draw_ending()

func _draw_background() -> void:
    var src_x := 70.0 + fposmod(camera_x * 0.055, 150.0)
    var src := Rect2(src_x, 65.0, 1280.0, 885.0)
    draw_texture_rect_region(backdrop, Rect2(0, -35, W, H + 75), src)
    var zone := active_zone
    if game_state == "title":
        zone = 0
    var mood := [Color(0.15, 0.10, 0.27, 0.28), Color(0.02, 0.16, 0.09, 0.13), Color(0.25, 0.09, 0.04, 0.30), Color(0.13, 0.02, 0.26, 0.57)][zone]
    draw_rect(Rect2(0, 0, W, H), mood)
    # Slow-moving atmospheric fog and distant lights.
    for i in 12:
        var fx := fposmod(float(i) * 263.3 + world_time * (8.0 + float(i % 3) * 7.0), W + 400.0) - 200.0
        var fy := 330.0 + sin(float(i) * 1.67 + world_time * 0.32) * 90.0
        draw_circle(Vector2(fx, fy), 65.0 + float(i % 5) * 22.0, Color(0.66, 0.94, 1.0, 0.014))
    if zone <= 1:
        _draw_dragon_in_sky()
    for i in 48:
        var x := fposmod(float(i * 347 % 1457) + sin(world_time * 0.65 + float(i)) * 20.0, W)
        var y := fposmod(float(i * 181 % 713) + world_time * (4.0 + float(i % 7)), H)
        var alpha := 0.17 + 0.26 * (0.5 + 0.5 * sin(world_time * 2.5 + float(i)))
        draw_circle(Vector2(x, y), 1.2 + float(i % 3) * 0.45, Color(GOLD.r, GOLD.g, GOLD.b, alpha))

func _draw_world() -> void:
    # Ground moss, trails, slabs, grass.
    draw_rect(Rect2(0, GROUND + 7.0, W, H - GROUND), Color(0.012, 0.033, 0.03, 0.52))
    draw_line(Vector2(0, GROUND + 6), Vector2(W, GROUND + 6), Color(0.43, 0.55, 0.31, 0.74), 4.0, true)
    for i in 130:
        var wx := float(i) * 67.0 + 21.0
        var sx := wx - camera_x
        if sx < -60.0 or sx > W + 60.0:
            continue
        var t := float(i) * 2.71
        draw_line(Vector2(sx, GROUND + 7), Vector2(sx + sin(t) * 7.0, GROUND - (7.0 + fposmod(float(i * 13), 14.0))), Color(0.23, 0.48, 0.25, 0.75), 1.5, true)
        if i % 5 == 0:
            draw_circle(Vector2(sx + 9, GROUND + 2), 3.0, Color(0.76, 0.64, 0.35))
    for i in 70:
        var wx := float(i) * 110.0 + 40.0
        var x := wx - camera_x
        if x > -90.0 and x < W + 90.0:
            draw_line(Vector2(x, GROUND + 15), Vector2(x + 54, GROUND + 15), Color(0.23, 0.26, 0.22, 0.33), 2.0)
    # Landmark arches and ruined sentinels.
    for landmark in [320.0, 1370.0, 2280.0, 3420.0, 4750.0, 5620.0, 6660.0]:
        if absf(landmark - camera_x - 640.0) < 1100.0:
            _draw_ruin(landmark - camera_x, landmark)
    for house_x in [4620.0, 5130.0, 5740.0]:
        if absf(house_x - camera_x) < 840.0:
            _draw_burned_house(house_x - camera_x)
    for altar_x in [170.0, 1860.0, 4440.0, 6330.0]:
        if absf(altar_x - camera_x) < 220.0:
            _draw_altar(altar_x - camera_x)
    if absf(4860.0 - camera_x) < 400.0:
        _draw_villager(4860.0 - camera_x)
    # Render dust and ground shadows behind actors.
    for e in enemies:
        if float(e["hp"]) > 0.0 and absf(float(e["x"]) - camera_x - 640.0) < 900.0:
            _draw_enemy(e)
    if boss_intro_done and boss_alive:
        _draw_boss()
    _draw_hero()

func _draw_dragon_in_sky() -> void:
    # A distant shadow on the horizon, an omen for later chapters.
    var x := 1030.0 + sin(world_time * 0.14) * 160.0 - fposmod(camera_x * 0.022, 130.0)
    var y := 205.0 + sin(world_time * 0.7) * 16.0
    var flap := sin(world_time * 2.4) * 37.0
    var ink := Color(0.07, 0.12, 0.17, 0.66)
    draw_polygon(PackedVector2Array([Vector2(x-5,y-5),Vector2(x-130,y-42-flap),Vector2(x-98,y+24),Vector2(x-51,y+13),Vector2(x-15,y+9)]),PackedColorArray([ink,ink,ink,ink,ink]))
    draw_polygon(PackedVector2Array([Vector2(x+4,y-9),Vector2(x+134,y-50-flap),Vector2(x+98,y+22),Vector2(x+50,y+12),Vector2(x+13,y+7)]),PackedColorArray([ink,ink,ink,ink,ink]))
    draw_polygon(PackedVector2Array([Vector2(x-22,y-7),Vector2(x+21,y-10),Vector2(x+68,y-26),Vector2(x+78,y-35),Vector2(x+88,y-20),Vector2(x+53,y-12),Vector2(x+25,y+8),Vector2(x-54,y+19)]),PackedColorArray([ink,ink,ink,ink,ink,ink,ink,ink]))
    draw_circle(Vector2(x+77,y-29),1.7,Color(1.0,0.46,0.18,0.9))

func _draw_burned_house(x: float) -> void:
    var shadow := Color(0.12,0.12,0.14,0.85)
    draw_rect(Rect2(x-70, GROUND-158, 146, 161),Color(0.23,0.18,0.15,0.9))
    draw_polygon(PackedVector2Array([Vector2(x-92,GROUND-149),Vector2(x-20,GROUND-244),Vector2(x+85,GROUND-171),Vector2(x+65,GROUND-149)]),PackedColorArray([shadow,Color(0.16,0.14,0.13),shadow,shadow]))
    draw_rect(Rect2(x-15,GROUND-99,39,102),Color(0.05,0.04,0.06,0.8))
    draw_rect(Rect2(x-57,GROUND-131,26,32),Color(0.04,0.05,0.05,0.9))
    draw_line(Vector2(x-73,GROUND-157),Vector2(x-78,GROUND-4),Color(0.07,0.07,0.08,0.9),5.0)
    for i in 4:
        var smoke_x := x - 7.0 + sin(world_time * 0.5 + float(i)) * 18.0
        var smoke_y := GROUND - 265.0 - float(i*30) - fposmod(world_time * 12.0, 45.0)
        draw_circle(Vector2(smoke_x,smoke_y),16.0+float(i)*7.0,Color(0.16,0.17,0.2,0.11))

func _draw_ruin(x: float, world_x: float) -> void:
    var h := 165.0 + fposmod(world_x * 1.7, 110.0)
    var stone := Color(0.18, 0.24, 0.25, 0.88)
    draw_rect(Rect2(x - 49, GROUND - h, 98, h + 10), stone)
    draw_rect(Rect2(x - 55, GROUND - h, 111, 19), Color(0.33, 0.40, 0.36, 0.94))
    draw_rect(Rect2(x - 27, GROUND - h + 42, 54, 66), Color(0.025, 0.1, 0.1, 0.8))
    draw_arc(Vector2(x, GROUND - h + 42), 26, PI, TAU, 22, Color(0.44, 0.46, 0.37, 0.93), 4.0, true)
    for j in 5:
        var row_y := GROUND - h + float(j * 36)
        draw_line(Vector2(x - 49, row_y), Vector2(x + 49, row_y + 6), Color(0.05, 0.09, 0.09, 0.55), 2.0)
    draw_line(Vector2(x + 50, GROUND - h), Vector2(x + 62, GROUND - h + 70), Color(0.08, 0.27, 0.13, 0.85), 5.0)
    draw_circle(Vector2(x + 63, GROUND - h + 35.0), 15.0, Color(0.09, 0.36, 0.17, 0.77))

func _draw_altar(x: float) -> void:
    var glow := 0.6 + 0.4 * sin(world_time * 3.3)
    draw_circle(Vector2(x, GROUND - 57), 71.0, Color(0.25, 0.9, 0.95, 0.055 + glow * 0.03))
    draw_polygon(PackedVector2Array([Vector2(x-40, GROUND), Vector2(x-29, GROUND-73), Vector2(x, GROUND-100), Vector2(x+29, GROUND-73), Vector2(x+40, GROUND)]), PackedColorArray([Color(0.16,0.23,0.27), Color(0.24,0.35,0.37), Color(0.42,0.46,0.46), Color(0.23,0.29,0.34), Color(0.11,0.18,0.19)]))
    draw_arc(Vector2(x, GROUND-53), 22, 0, TAU, 35, Color(0.34, 0.89, 0.93, glow), 3.0, true)
    draw_line(Vector2(x-14, GROUND-53), Vector2(x+15, GROUND-53), CYAN, 2.0)
    draw_line(Vector2(x, GROUND-68), Vector2(x, GROUND-38), CYAN, 2.0)
    for i in 5:
        var a := world_time * 0.8 + float(i) * TAU / 5.0
        draw_circle(Vector2(x + cos(a)*37.0, GROUND - 55.0 + sin(a)*22.0), 2.4, Color(0.52, 1, 1, 0.9))

func _draw_villager(x: float) -> void:
    draw_ellipse_local(Vector2(x, GROUND), Vector2(23, 6), Color(0, 0, 0, 0.5))
    draw_polygon(PackedVector2Array([Vector2(x-21,GROUND-7),Vector2(x+20,GROUND-7),Vector2(x+15,GROUND-101),Vector2(x-14,GROUND-101)]), PackedColorArray([Color(0.28,0.21,0.19),Color(0.24,0.16,0.16),Color(0.33,0.26,0.20),Color(0.18,0.12,0.13)]))
    draw_circle(Vector2(x,GROUND-123), 19.0, Color(0.84,0.62,0.45))
    draw_polygon(PackedVector2Array([Vector2(x-29,GROUND-123),Vector2(x,GROUND-160),Vector2(x+29,GROUND-123)]),PackedColorArray([Color(0.16,0.21,0.19),Color(0.17,0.24,0.18),Color(0.11,0.16,0.14)]))
    _text(Vector2(x-28, GROUND-178), "!", 33, GOLD)

func draw_ellipse_local(center: Vector2, radius: Vector2, color: Color) -> void:
    draw_set_transform(center, 0.0, radius)
    draw_circle(Vector2.ZERO, 1.0, color)
    draw_set_transform(Vector2.ZERO)

func _draw_enemy(e: Dictionary) -> void:
    var x := float(e["x"]) - camera_x
    var y := float(e["y"])
    var phase := float(e["phase"])
    var ghost := str(e["type"]) == "wraith"
    var cultist := str(e["type"]) == "cultist"
    var scale_x := float(e["dir"])
    draw_ellipse_local(Vector2(x, GROUND + 3), Vector2(27, 7), Color(0, 0, 0, 0.36))
    draw_set_transform(Vector2(x, y), 0.0, Vector2(scale_x, 1.0))
    var damaged := float(e["hurt"]) > 0.0
    if cultist:
        draw_polygon(PackedVector2Array([Vector2(-30,-5),Vector2(-20,-105),Vector2(5,-143),Vector2(29,-105),Vector2(31,-5)]), PackedColorArray([VIOLET if damaged else Color(0.10,0.06,0.17), Color(0.22,0.12,0.28),Color(0.12,0.07,0.19),Color(0.27,0.17,0.31),Color(0.1,0.08,0.15)]))
        draw_circle(Vector2(0,-105), 18, Color(0.06,0.05,0.10))
        draw_circle(Vector2(8,-109), 3.2, Color(0.85,0.5,1))
        draw_line(Vector2(28,-18),Vector2(34,-149),Color(0.16,0.1,0.10),5.0)
        draw_circle(Vector2(34,-149),11.0,Color(0.68,0.3,1.0,0.72))
    elif ghost:
        var bob := sin(phase * 2.2) * 10.0
        draw_polygon(PackedVector2Array([Vector2(-30,bob-7),Vector2(-26,bob-89),Vector2(0,bob-117),Vector2(27,bob-88),Vector2(25,bob-11),Vector2(4,bob-29)]), PackedColorArray([Color(0.28,0.38,0.51,0.65),Color(0.19,0.23,0.37,0.83),Color(0.10,0.14,0.28,0.92),Color(0.23,0.28,0.40,0.83),Color(0.16,0.23,0.37,0.67),Color(0.13,0.23,0.37,0.76)]))
        draw_circle(Vector2(0,bob-85), 16.0, Color(0.035,0.06,0.11))
        draw_circle(Vector2(7,bob-88),3.4, CYAN)
    else:
        var wolf_color := RED if damaged else Color(0.18, 0.21, 0.20)
        draw_polygon(PackedVector2Array([Vector2(-37,-39),Vector2(-29,-73),Vector2(19,-78),Vector2(45,-51),Vector2(31,-38)]), PackedColorArray([wolf_color,wolf_color,Color(0.12,0.14,0.17),Color(0.26,0.29,0.29),wolf_color]))
        draw_polygon(PackedVector2Array([Vector2(14,-75),Vector2(23,-114),Vector2(32,-91),Vector2(49,-83),Vector2(58,-55)]),PackedColorArray([Color(0.26,0.26,0.26),wolf_color,wolf_color,Color(0.13,0.16,0.17),wolf_color]))
        draw_line(Vector2(-22,-48),Vector2(-22,-7),wolf_color,8.0)
        draw_line(Vector2(23,-49),Vector2(20,-7),wolf_color,8.0)
        draw_circle(Vector2(43,-84),3.2,Color(1,0.72,0.18))
    draw_set_transform(Vector2.ZERO)
    var hp_frac := float(e["hp"]) / float(e["max_hp"])
    draw_rect(Rect2(x - 27.0, y - (163.0 if cultist else 143.0), 54.0, 4.0),Color(0.08,0.1,0.1,0.88))
    draw_rect(Rect2(x - 27.0, y - (163.0 if cultist else 143.0), 54.0 * hp_frac, 4.0),Color(0.79,0.29,0.57))

func _draw_boss() -> void:
    var x := 7030.0 - camera_x
    if x < -230.0 or x > W + 230.0:
        return
    var bob := sin(world_time * 1.8) * 14.0
    var center := Vector2(x, GROUND - 130.0 + bob)
    draw_circle(center, 150.0, Color(0.55,0.16,0.89,0.10))
    draw_arc(center, 120.0, world_time*0.35, world_time*0.35 + TAU*0.75, 76, Color(0.66,0.35,1.0,0.54),2.5,true)
    draw_arc(center, 95.0, -world_time*0.53, -world_time*0.53 + TAU*0.72, 76, Color(0.85,0.68,1.0,0.68),2.5,true)
    draw_set_transform(center,0.0,Vector2.ONE)
    draw_polygon(PackedVector2Array([Vector2(-57,70),Vector2(-66,-38),Vector2(-24,-102),Vector2(0,-113),Vector2(25,-102),Vector2(67,-36),Vector2(57,74),Vector2(4,60)]),PackedColorArray([Color(0.09,0.04,0.15),Color(0.22,0.08,0.29),Color(0.26,0.1,0.34),Color(0.10,0.03,0.19),Color(0.18,0.05,0.30),Color(0.28,0.1,0.40),Color(0.09,0.03,0.14),Color(0.1,0.04,0.18)]))
    draw_circle(Vector2(0,-74),32,Color(0.04,0.02,0.09))
    draw_circle(Vector2(-11,-77),4,CYAN)
    draw_circle(Vector2(12,-77),4,VIOLET)
    draw_line(Vector2(64,50),Vector2(98,-109),Color(0.28,0.23,0.27),8.0)
    draw_circle(Vector2(98,-108),24,Color(0.75,0.33,0.96,0.26))
    draw_circle(Vector2(98,-108),12,Color(0.76,0.46,1.0))
    draw_set_transform(Vector2.ZERO)
    draw_rect(Rect2(W * 0.31, 112, W * 0.38, 11),Color(0.03,0.02,0.08,0.85))
    draw_rect(Rect2(W * 0.31, 112, W * 0.38 * boss_hp / 260.0, 11),Color(0.73,0.36,0.92))
    _text(Vector2(W*0.5,101),tr_ru("МОРВЕН · ХРАНИТЕЛЬ ШИПОВ", "MORWEN · KEEPER OF THORNS"),21,CREAM,HORIZONTAL_ALIGNMENT_CENTER,640)

func _draw_hero() -> void:
    var pos := Vector2(player.x - camera_x, player.y)
    if invulnerability > 0.0 and int(world_time * 18) % 2 == 0:
        return
    draw_ellipse_local(Vector2(pos.x, GROUND + 3), Vector2(32, 8), Color(0,0,0,0.52))
    var run_bob := sin(world_time * 13.0) * 4.0 if moving and grounded else 0.0
    var t := Vector2(pos.x, pos.y + run_bob)
    draw_set_transform(t, 0.0, Vector2(float(facing), 1.0))
    # Windblown crimson mantle, greaves, cuirass and glowing sigil.
    var billow := sin(world_time*7.3)*11.0
    draw_polygon(PackedVector2Array([Vector2(-18,-111),Vector2(-65+billow,-93),Vector2(-79+billow,-12),Vector2(-16,-45)]),PackedColorArray([Color(0.72,0.17,0.18),Color(0.46,0.09,0.13),Color(0.33,0.07,0.12),Color(0.8,0.20,0.2)]))
    draw_line(Vector2(-14,-41),Vector2(-17,-5),Color(0.13,0.17,0.22),13.0)
    draw_line(Vector2(15,-41),Vector2(16,-5),Color(0.18,0.21,0.24),13.0)
    draw_polygon(PackedVector2Array([Vector2(-24,-110),Vector2(20,-116),Vector2(26,-49),Vector2(-20,-45)]),PackedColorArray([Color(0.16,0.19,0.24),Color(0.33,0.37,0.37),Color(0.11,0.15,0.19),Color(0.2,0.23,0.25)]))
    draw_polygon(PackedVector2Array([Vector2(-14,-100),Vector2(6,-101),Vector2(16,-79),Vector2(0,-73)]),PackedColorArray([Color(0.55,0.48,0.33),Color(0.66,0.58,0.38),Color(0.21,0.21,0.24),Color(0.30,0.29,0.28)]))
    draw_circle(Vector2(1,-88), 7.0, Color(0.98,0.67,0.22))
    draw_circle(Vector2(1,-88), 3.0, Color(1.0,0.93,0.62))
    draw_line(Vector2(19,-101),Vector2(31,-60),Color(0.18,0.22,0.25),12.0)
    draw_circle(Vector2(0,-131), 22, Color(0.72,0.55,0.40))
    draw_polygon(PackedVector2Array([Vector2(-24,-133),Vector2(-17,-160),Vector2(14,-163),Vector2(24,-136),Vector2(16,-148),Vector2(-12,-146)]),PackedColorArray([Color(0.13,0.17,0.19),Color(0.28,0.30,0.32),Color(0.39,0.40,0.37),Color(0.14,0.18,0.21),Color(0.18,0.19,0.22),Color(0.25,0.26,0.26)]))
    draw_circle(Vector2(15,-132), 3.1, Color(0.86,0.91,0.96))
    # One-handed sword and swept slash.
    draw_line(Vector2(31,-61),Vector2(53,-113),Color(0.57,0.64,0.66),5.0)
    draw_line(Vector2(28,-78),Vector2(55,-67),Color(0.71,0.55,0.31),5.0)
    if attack_timer > 0.0:
        var transparency := attack_timer / 0.25
        draw_arc(Vector2(13,-87), 85.0, -1.42, 1.14, 26, Color(0.58,0.94,1.0,transparency*0.82), 10.0, true)
        draw_arc(Vector2(13,-87), 97.0, -1.42, 1.14, 26, Color(1.0,0.79,0.44,transparency*0.35), 5.0, true)
    draw_set_transform(Vector2.ZERO)

func _draw_effects() -> void:
    for p in projectiles:
        var position := Vector2(p["pos"]) - Vector2(camera_x, 0)
        if position.x < -30 or position.x > W + 30: continue
        var fire := str(p["kind"]) == "fire"
        var color := Color(1.0,0.48,0.15) if fire else VIOLET
        draw_circle(position, 22.0 if fire else 17.0, Color(color.r,color.g,color.b,0.16))
        draw_circle(position, 11.0 if fire else 8.0, Color(color.r,color.g,color.b,0.67))
        draw_circle(position, 4.8, CREAM)
    for p in motes:
        var position := Vector2(p["p"]) - Vector2(camera_x, 0)
        if position.x < -20 or position.x > W + 20: continue
        var c: Color = p["color"]
        c.a = minf(1.0, float(p["life"]) / float(p["max"]))
        draw_circle(position, float(p["size"]) * c.a, c)

func _text(pos: Vector2, content: String, size: int = 22, color: Color = CREAM, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
    draw_string(ThemeDB.fallback_font, pos + Vector2(1,2), content, align, width, size, Color(0.01,0.02,0.035,0.92))
    draw_string(ThemeDB.fallback_font, pos, content, align, width, size, color)

func _draw_hud() -> void:
    if game_state == "title":
        return
    draw_rect(Rect2(20,18, 336, 95), Color(0.018,0.025,0.04,0.78))
    draw_rect(Rect2(20,18, 336, 95), Color(0.56,0.43,0.27,0.36),false,2.0)
    _text(Vector2(42,45),tr_ru("СТРАЖ ПЛАМЕНИ", "FLAMEWARDEN"),18,GOLD)
    _bar(Rect2(42,57, 276,14),hp/MAX_HP,Color(0.96,0.31,0.28),"HP")
    _bar(Rect2(42,83, 276,11),mana/MAX_MANA,Color(0.34,0.67,1.0),"MP")
    var names := ZONE_NAMES if language == "ru" else EN_ZONE_NAMES
    var quests := QUESTS if language == "ru" else EN_QUESTS
    draw_rect(Rect2(375, 18, 524, 88), Color(0.018,0.025,0.04,0.73))
    draw_rect(Rect2(375, 18, 524, 88), Color(0.56,0.43,0.27,0.27),false,1.5)
    _text(Vector2(392, 48),names[active_zone],24,GOLD)
    _text(Vector2(392, 82),quests[active_zone],17,CREAM)
    draw_rect(Rect2(920, 19, 238, 66),Color(0.018,0.025,0.04,0.72))
    _text(Vector2(942, 57),"✦ %d" % souls,26,CYAN)
    if game_state == "playing":
        _text(Vector2(1194, 62),"Ⅱ",30,GOLD)
    if message_timer > 0.0 and game_state == "playing":
        var box := Rect2(200, 453, 880, 77)
        draw_rect(box, Color(0.014,0.023,0.035,0.82))
        draw_rect(box, Color(0.67,0.52,0.32,0.45),false,2.0)
        _text(Vector2(217, 499),message,19,message_color,HORIZONTAL_ALIGNMENT_CENTER, 845)
    if game_state == "playing":
        _draw_controls()

func _bar(rect: Rect2, amount: float, tint: Color, kind: String) -> void:
    draw_rect(rect,Color(0.05,0.06,0.08,0.95))
    var r := Rect2(rect.position + Vector2(2,2),Vector2((rect.size.x-4)*clampf(amount,0,1),rect.size.y-4))
    draw_rect(r,tint)
    draw_rect(rect,Color(0.75,0.68,0.55,0.4),false,1.0)
    _text(rect.position + Vector2(-26,rect.size.y-1),kind,11,CREAM)

func _draw_controls() -> void:
    var base_alpha := 0.5 if touch_controls else 0.27
    _control_button(Rect2(18,587,124,110),"◀",base_alpha, _button_down("left"))
    _control_button(Rect2(145,587,128,110),"▶",base_alpha, _button_down("right"))
    _control_button(Rect2(840,587,108,110),"E",base_alpha, false)
    _control_button(Rect2(949,587,106,110),"⚔",base_alpha, false)
    _control_button(Rect2(1056,587,111,110),"✦",base_alpha, false)
    _control_button(Rect2(1168,587,98,110),"↑",base_alpha, false)
    if not touch_controls:
        _text(Vector2(34,575),"A / D",14,CREAM)
        _text(Vector2(850,575),"E",14,CREAM)
        _text(Vector2(958,575),"J",14,CREAM)
        _text(Vector2(1067,575),"K",14,CREAM)
        _text(Vector2(1173,575),"SPACE",14,CREAM)

func _control_button(rect: Rect2, glyph: String, alpha: float, pressed: bool) -> void:
    draw_rect(rect,Color(0.05,0.12,0.16,alpha * 0.66))
    draw_rect(rect,Color(0.74,0.87,0.90,alpha * (1.6 if pressed else 1.0)),false,2.5)
    _text(Vector2(rect.position.x + 2,rect.position.y + 75),glyph,39,Color(0.91,0.95,1.0,alpha + 0.35),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x - 4)

func _veil(opacity: float = 0.82) -> void:
    draw_rect(Rect2(0,0,W,H),Color(0.018,0.025,0.04,opacity))

func _menu_button(rect: Rect2, title: String, tint: Color = GOLD) -> void:
    draw_rect(rect,Color(0.08,0.11,0.15,0.92))
    draw_rect(rect,tint,false,2.5)
    draw_rect(Rect2(rect.position.x + 7,rect.position.y + 7,rect.size.x - 14,rect.size.y - 14),Color(tint.r,tint.g,tint.b,0.065))
    _text(Vector2(rect.position.x + 8,rect.position.y + rect.size.y * 0.62),title,24,tint,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x - 16)

func _draw_title() -> void:
    _veil(0.66)
    draw_rect(Rect2(210,108,860,489),Color(0.018,0.025,0.043,0.71))
    draw_rect(Rect2(210,108,860,489),Color(0.68,0.48,0.27,0.49),false,2.0)
    _text(Vector2(250,190),tr_ru("ПЕПЕЛ СЕМИ КОРОЛЕВСТВ", "ASH OF THE SEVEN KINGDOMS"),47,GOLD,HORIZONTAL_ALIGNMENT_CENTER,780)
    draw_line(Vector2(410,217),Vector2(869,217),GOLD,2.0)
    _text(Vector2(270,267),tr_ru("Семь сердец. Семь проклятий. Одна забытая клятва.","Seven hearts. Seven curses. One forgotten oath."),22,CREAM,HORIZONTAL_ALIGNMENT_CENTER,740)
    _text(Vector2(290,331),tr_ru("Войди в мир драконов, призраков и запретной магии.","Enter a world of dragons, spectres and forbidden magic."),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER,700)
    _text(Vector2(280,370),tr_ru("Открой правду о падении древних королевств.","Uncover the truth behind the ancient kingdoms' fall."),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER,720)
    _menu_button(Rect2(425,465,430,76),tr_ru("ПРОБУДИТЬСЯ", "AWAKEN"))
    _text(Vector2(310,581),tr_ru("Enter — начать   •   A/D — идти   •   Space — прыгать   •   J — меч   •   K — огонь", "Enter — start   •   A/D — move   •   Space — jump   •   J — sword   •   K — fire"),17,CREAM,HORIZONTAL_ALIGNMENT_CENTER,660)
    _menu_button(Rect2(1060,36,156,62),"RU / EN",CYAN)
    _text(Vector2(0,679),"PLAY EVERYWHERE  •  PROLOGUE 0.1",16,CREAM,HORIZONTAL_ALIGNMENT_CENTER,W)

func _draw_paused() -> void:
    _veil(0.78)
    _text(Vector2(0,284),tr_ru("ПАУЗА", "PAUSED"),54,GOLD,HORIZONTAL_ALIGNMENT_CENTER,W)
    _text(Vector2(0,365),tr_ru("Нажми Esc или P, либо коснись экрана, чтобы продолжить.","Press Esc or P, or tap anywhere to continue."),23,CREAM,HORIZONTAL_ALIGNMENT_CENTER,W)

func _draw_dead() -> void:
    _veil(0.86)
    _text(Vector2(0,282),tr_ru("СТРАЖ ПАЛ", "THE WARDEN HAS FALLEN"),56,RED,HORIZONTAL_ALIGNMENT_CENTER,W)
    _text(Vector2(0,354),tr_ru("Но древнее пламя ещё не погасло.", "Yet the ancient flame still burns."),23,CREAM,HORIZONTAL_ALIGNMENT_CENTER,W)
    _menu_button(Rect2(425,460,430,90),tr_ru("ВОЗРОДИТЬСЯ У АЛТАРЯ", "RETURN TO SANCTUARY"))

func _draw_choice() -> void:
    _veil(0.87)
    _text(Vector2(0,191),tr_ru("СЕРДЦЕ ДРАКОНА", "HEART OF THE DRAGON"),51,GOLD,HORIZONTAL_ALIGNMENT_CENTER,W)
    _text(Vector2(210,285),tr_ru("Морвен побеждён. Во тьме алтаря бьётся сердце заточённого дракона.","Morwen has fallen. A captive dragon's heart pulses inside the altar."),21,CREAM,HORIZONTAL_ALIGNMENT_CENTER,860)
    _text(Vector2(220,330),tr_ru("Ты можешь освободить его... или забрать его силу себе.","You may set it free... or claim its power for yourself."),21,CREAM,HORIZONTAL_ALIGNMENT_CENTER,840)
    _menu_button(Rect2(235,440,370,100),tr_ru("F · ОСВОБОДИТЬ", "F · SET FREE"),CYAN)
    _menu_button(Rect2(676,440,370,100),tr_ru("G · ЗАБРАТЬ СИЛУ", "G · TAKE THE POWER"),RED)

func _draw_ending() -> void:
    _veil(0.87)
    var liberated := soul_choice == "free"
    _text(Vector2(0,200),tr_ru("ПЕРВАЯ ПЕЧАТЬ РАЗРУШЕНА", "THE FIRST SEAL IS BROKEN"),49,CYAN if liberated else RED,HORIZONTAL_ALIGNMENT_CENTER,W)
    var ending_ru := "На востоке впервые за три столетия загорается звезда. Где-то в небесах пробуждается дракон." if liberated else "Сила дракона пульсирует в твоей крови. Вдали раздаётся тревожный рёв."
    var ending_en := "For the first time in three centuries, a star shines in the east. A dragon awakens." if liberated else "Dragonfire pulses through your veins. A distant, troubled roar answers."
    _text(Vector2(100,296),tr_ru(ending_ru,ending_en),20,CREAM,HORIZONTAL_ALIGNMENT_CENTER,1080)
    _text(Vector2(200,376),tr_ru("Конец пролога · Продолжение следует", "End of the prologue · To be continued"),25,GOLD,HORIZONTAL_ALIGNMENT_CENTER,880)
    _menu_button(Rect2(425,492,430,86),tr_ru("ПРОЙТИ ЗАНОВО", "PLAY AGAIN"))
    _text(Vector2(0,655),tr_ru("Спасибо, что сыграли в первый прототип игры!", "Thank you for playing the first prototype!"),17,CREAM,HORIZONTAL_ALIGNMENT_CENTER,W)
