extends RefCounted
## Painted, articulated Flamewarden. All coordinates are viewport pixels.
## Rendering stays in the game's canvas so fog, effects and menus retain their order.

const ATLAS: Texture2D = preload("res://art/flamewarden_atlas.png")
const REGIONS: Array[Rect2] = [
    Rect2(11, 4, 263, 310), Rect2(354, 11, 225, 300),
    Rect2(656, 66, 260, 236), Rect2(1050, 3, 97, 311),
    Rect2(28, 337, 261, 271), Rect2(407, 322, 124, 294),
    Rect2(718, 324, 128, 293), Rect2(1032, 336, 150, 265),
    Rect2(75, 633, 160, 300), Rect2(406, 633, 113, 301),
    Rect2(664, 706, 248, 180), Rect2(942, 631, 301, 303),
    Rect2(65, 950, 180, 300), Rect2(316, 972, 305, 264),
    Rect2(698, 1007, 163, 180), Rect2(1025, 965, 150, 261)
]
const STRIDE: float = 118.0
const SWORD_DURATION: float = 0.46
const CAST_DURATION: float = 0.54

var time: float = 0.0
var phase: float = 0.0
var run_blend: float = 0.0
var air_blend: float = 0.0
var rise: float = 0.0
var cape_wind: float = 0.0
var landing: float = 0.0
var landing_velocity: float = 0.0
var landing_age: float = 2.0
var hurt_age: float = 2.0
var sword_age: float = 2.0
var cast_age: float = 2.0
var death_age: float = -1.0
var combo: int = -1
var last_grounded: bool = true
var state_name: String = "idle"
var pose: Dictionary = {}
var actor_transform: Transform2D = Transform2D.IDENTITY
var actor_tint: Color = Color.WHITE

func _init() -> void:
    _build_pose()

func reset() -> void:
    time = 0.0
    phase = 0.0
    run_blend = 0.0
    air_blend = 0.0
    rise = 0.0
    cape_wind = 0.0
    landing = 0.0
    landing_velocity = 0.0
    landing_age = 2.0
    hurt_age = 2.0
    sword_age = 2.0
    cast_age = 2.0
    death_age = -1.0
    combo = -1
    last_grounded = true
    state_name = "idle"
    _build_pose()

func slash() -> void:
    combo = (combo + 1) % 3
    sword_age = 0.0
    cast_age = CAST_DURATION

func cast() -> void:
    cast_age = 0.0

func hurt() -> void:
    hurt_age = 0.0

func die() -> void:
    death_age = 0.0
    sword_age = SWORD_DURATION
    cast_age = CAST_DURATION

func advance(delta: float, speed: float, on_ground: bool, vertical_speed: float, mode: String) -> void:
    # Pause/choice freeze secondary motion as well as the combat pose.
    if mode not in ["playing", "title", "dead"]:
        return
    var dt: float = clampf(delta, 0.0, 0.05)
    var blend: float = 1.0 - exp(-dt * 13.0)
    time += dt
    sword_age += dt
    cast_age += dt
    hurt_age += dt
    landing_age += dt
    if death_age >= 0.0:
        death_age += dt
        speed = 0.0
    var target_run: float = clampf(absf(speed) / 290.0, 0.0, 1.0) if on_ground else 0.0
    run_blend = lerpf(run_blend, target_run, blend)
    air_blend = lerpf(air_blend, 0.0 if on_ground else 1.0, blend)
    rise = lerpf(rise, clampf(vertical_speed / 700.0, -1.0, 1.0), blend)
    cape_wind = lerpf(cape_wind, absf(speed) / 290.0 * 25.0 + air_blend * 12.0, 1.0 - exp(-dt * 5.0))
    if on_ground and not last_grounded and death_age < 0.0:
        landing_velocity = 52.0
        landing_age = 0.0
    last_grounded = on_ground
    # Stable damped spring; substeps keep landing smooth on slower phones.
    for step in range(3):
        var h: float = dt / 3.0
        landing_velocity += (-landing * 155.0 - landing_velocity * 18.0) * h
        landing += landing_velocity * h
    if on_ground and absf(speed) > 0.1:
        phase = fposmod(phase + absf(speed) * dt / STRIDE * TAU, TAU)
    _build_pose()

func _ease(t: float) -> float:
    var v: float = clampf(t, 0.0, 1.0)
    return v * v * (3.0 - 2.0 * v)

func _foot(cycle: float, rear: bool) -> Vector2:
    var u: float = fposmod(cycle / TAU, 1.0)
    var step: Vector2
    # A planted foot travels backwards at the character's world speed.
    if u < 0.62:
        step = Vector2(36.58 - STRIDE * u, -8.0)
    else:
        var swing: float = (u - 0.62) / 0.38
        step = Vector2(lerpf(-36.58, 36.58, _ease(swing)), -8.0 - sin(swing * PI) * 21.0)
    var rest := Vector2(-10.0 if rear else 10.0, -8.0)
    var result: Vector2 = rest.lerp(step, run_blend)
    var in_air := Vector2(-21.0 if rear else 23.0, -16.0 if rear else -31.0)
    in_air.y += maxf(rise, 0.0) * 12.0
    result = result.lerp(in_air, air_blend)
    return result

func _attack(t: float, variant: int) -> Dictionary:
    var wind: float = _ease(t / 0.055)
    var strike: float = _ease((t - 0.055) / 0.16)
    var recover: float = _ease((t - 0.26) / 0.20)
    var hand: Vector2
    var angle: float
    var body: float
    if variant == 1:
        hand = Vector2(19, -72).lerp(Vector2(38, -123), strike)
        angle = lerpf(2.70, -0.62, strike)
        body = lerpf(0.17, -0.10, strike)
    elif variant == 2:
        hand = Vector2(5, -105).lerp(Vector2(57, -105), strike)
        angle = lerpf(0.32, 1.47, wind)
        body = lerpf(-0.12, 0.20, strike)
    else:
        hand = Vector2(29, -78).lerp(Vector2(2, -135), wind)
        hand = hand.lerp(Vector2(43, -72), strike)
        angle = lerpf(0.25, -1.30, wind)
        angle = lerpf(angle, 2.50, strike)
        body = lerpf(-0.15 * wind, 0.20, strike)
    return {"hand": hand.lerp(Vector2(30, -76), recover),
        "angle": lerpf(angle, 0.29, recover), "body": body * (1.0 - recover)}

func _build_pose() -> void:
    var breath: float = sin(time * 2.5)
    var bob: float = -(1.0 - cos(phase * 2.0)) * 1.7 * run_blend
    var hip := Vector2(0.0, -66.0 + bob + landing)
    var torso_angle: float = 0.075 * run_blend + breath * 0.008
    var hand := Vector2(30.0 + sin(phase + PI) * 15.0 * run_blend,
        -76.0 + bob + cos(phase) * 5.0 * run_blend + breath * 0.4)
    var offhand := Vector2(-17.0 + sin(phase) * 20.0 * run_blend, -78.0 + bob)
    var blade: float = 0.29 - sin(phase) * 0.16 * run_blend
    state_name = "idle"
    if run_blend > 0.12:
        state_name = "run"
    if air_blend > 0.3:
        state_name = "jump" if rise < 0.0 else "fall"
        hand = hand.lerp(Vector2(29, -100), air_blend)
        offhand = offhand.lerp(Vector2(-28, -100), air_blend)
        torso_angle -= air_blend * 0.08
    if cast_age < CAST_DURATION:
        state_name = "cast"
        var charge: float = _ease(cast_age / 0.10)
        var recover: float = _ease((cast_age - 0.25) / 0.29)
        offhand = offhand.lerp(Vector2(43, -109), charge * (1.0 - recover))
        torso_angle -= sin(cast_age / CAST_DURATION * PI) * 0.11
    if sword_age < SWORD_DURATION:
        state_name = "slash"
        var attack: Dictionary = _attack(sword_age, combo)
        hand = attack["hand"]
        blade = float(attack["angle"])
        torso_angle += float(attack["body"])
    if hurt_age < 0.32:
        state_name = "hurt"
        var flinch: float = sin(hurt_age / 0.32 * PI)
        torso_angle -= flinch * 0.20
        hip.x -= flinch * 4.0
        hand += Vector2(-7.0, 5.0) * flinch
    if death_age >= 0.0:
        state_name = "death"
        var collapse: float = _ease(death_age / 0.85)
        hip.y += sin(collapse * PI) * 14.0
        torso_angle += sin(collapse * PI) * 0.28
        hand = hand.lerp(Vector2(36, -38), collapse)
        offhand = offhand.lerp(Vector2(-15, -45), collapse)
    pose = {"hip": hip, "body": torso_angle, "hand": hand,
        "offhand": offhand, "blade": blade, "rear_foot": _foot(phase + PI, true),
        "front_foot": _foot(phase, false), "breath": breath}

func _part(canvas: Node2D, cell: int, joint: Vector2, size: Vector2, anchor: Vector2,
        angle: float = 0.0, tint: Color = Color.WHITE) -> void:
    canvas.draw_set_transform_matrix(actor_transform * Transform2D(angle, joint))
    canvas.draw_texture_rect_region(ATLAS, Rect2(-anchor, size), REGIONS[cell], tint * actor_tint)

func _ik(start: Vector2, target: Vector2, upper: float, lower: float, bend: float = 1.0) -> Vector2:
    var delta: Vector2 = target - start
    var distance: float = clampf(delta.length(), 0.1, upper + lower - 0.01)
    var cosine: float = clampf((upper * upper + distance * distance - lower * lower) / (2.0 * upper * distance), -1.0, 1.0)
    var angle: float = delta.angle() - acos(cosine) * bend
    return start + Vector2(cos(angle), sin(angle)) * upper

func _leg(canvas: Node2D, hip: Vector2, foot: Vector2, rear: bool) -> void:
    var tint := Color(0.63, 0.69, 0.78) if rear else Color.WHITE
    var knee: Vector2 = _ik(hip, foot, 36.0, 35.0, -1.0)
    var thigh_angle: float = (knee - hip).angle() - PI * 0.5
    var shin_angle: float = (foot - knee).angle() - PI * 0.5
    _part(canvas, 8, hip, Vector2(18, 42), Vector2(9, 3), thigh_angle, tint)
    _part(canvas, 9, knee, Vector2(14, 40), Vector2(7, 3), shin_angle, tint)
    var toe: float = clampf((foot.y + 8.0) / 30.0, -0.42, 0.0)
    _part(canvas, 10, foot, Vector2(25, 18), Vector2(9, 10), toe, tint)

func _arm(canvas: Node2D, shoulder: Vector2, hand: Vector2, rear: bool) -> Vector2:
    var tint := Color(0.67, 0.72, 0.81) if rear else Color.WHITE
    # Clamp the wrist too: stretched arms must never detach at the elbow.
    var wrist: Vector2 = shoulder + (hand - shoulder).limit_length(50.0)
    var elbow: Vector2 = _ik(shoulder, wrist, 26.0, 25.0, -1.0 if rear else 1.0)
    var upper_angle: float = (elbow - shoulder).angle() - PI * 0.5
    var lower_angle: float = (wrist - elbow).angle() - PI * 0.5
    _part(canvas, 5, shoulder, Vector2(15, 31), Vector2(7.5, 3), upper_angle, tint)
    _part(canvas, 6, elbow, Vector2(14, 29), Vector2(7, 3), lower_angle, tint)
    _part(canvas, 7, wrist, Vector2(12, 18), Vector2(6, 4), lower_angle * 0.45, tint)
    return wrist

func _cape_point(u: float, v: float) -> Vector2:
    var weight: float = v * v
    var flutter: float = sin(time * 5.0 - v * 4.2) * 3.5 + sin(time * 9.0 - v * 7.0) * 1.3
    return Vector2((u - 0.88) * 66.0 - cape_wind * weight + flutter * weight,
        v * 100.0 - cape_wind * v * 0.32 + sin(time * 5.0 - v * 3.0) * weight * 2.0)

func _draw_cape(canvas: Node2D, pin: Vector2) -> void:
    canvas.draw_set_transform_matrix(actor_transform * Transform2D(0.0, pin))
    var region: Rect2 = REGIONS[11]
    var atlas_size: Vector2 = ATLAS.get_size()
    # Nine textured strips deform the painted fabric without stretching its pin.
    for row in range(9):
        var top: float = float(row) / 9.0
        var bottom: float = float(row + 1) / 9.0
        var points := PackedVector2Array([_cape_point(0.0, top), _cape_point(1.0, top),
            _cape_point(1.0, bottom), _cape_point(0.0, bottom)])
        var uv := PackedVector2Array([
            (region.position + region.size * Vector2(0, top)) / atlas_size,
            (region.position + region.size * Vector2(1, top)) / atlas_size,
            (region.position + region.size * Vector2(1, bottom)) / atlas_size,
            (region.position + region.size * Vector2(0, bottom)) / atlas_size])
        canvas.draw_polygon(points, PackedColorArray([Color(0.9, 0.87, 0.94) * actor_tint]), uv, ATLAS)

func _glow(canvas: Node2D, center: Vector2, radius: float, color: Color, strength: float) -> void:
    canvas.draw_set_transform_matrix(actor_transform)
    for layer in range(4, 0, -1):
        var f: float = float(layer) / 4.0
        canvas.draw_circle(center, radius * f, Color(color.r, color.g, color.b,
            strength * (1.0 - f * 0.7) * actor_tint.a))

func _draw_trail(canvas: Node2D) -> void:
    if sword_age < 0.06 or sword_age > 0.31 or combo == 2:
        return
    canvas.draw_set_transform_matrix(actor_transform)
    var outer := PackedVector2Array()
    var inner := PackedVector2Array()
    var fade: float = 1.0 - _ease((sword_age - 0.21) / 0.10)
    for i in range(12):
        var f: float = float(i) / 11.0
        var past: float = maxf(0.055, sword_age - (1.0 - f) * 0.10)
        var sample: Dictionary = _attack(past, combo)
        var hand: Vector2 = sample["hand"]
        var direction := Vector2(0, -1).rotated(float(sample["angle"]))
        outer.append(hand + direction * 71.0)
        inner.append(hand + direction * 52.0)
    for i in range(11):
        if outer[i].distance_squared_to(outer[i + 1]) < 0.25:
            continue
        var points := PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
        var alpha: float = float(i + 1) / 11.0 * 0.42 * fade * actor_tint.a
        canvas.draw_polygon(points, PackedColorArray([Color(0.65, 0.89, 1.0, alpha * 0.8),
            Color(0.65, 0.89, 1.0, alpha), Color(1.0, 0.68, 0.28, 0.0), Color(1.0, 0.68, 0.28, 0.0)]))
    canvas.draw_polyline(outer, Color(0.84, 0.97, 1.0, fade * 0.72 * actor_tint.a), 1.5, true)

func draw_actor(canvas: Node2D, origin: Vector2, ground_y: float, facing: int,
        opacity: float = 1.0, scale_factor: float = 1.0) -> void:
    var height: float = maxf(0.0, ground_y - origin.y)
    var shadow_size: float = lerpf(30.0, 16.0, clampf(height / 170.0, 0.0, 1.0))
    canvas.draw_set_transform(Vector2(origin.x, ground_y + 3.0), 0.0,
        Vector2(shadow_size * scale_factor, 6.0 * scale_factor))
    canvas.draw_circle(Vector2.ZERO, 1.0, Color(0.0, 0.015, 0.025, 0.4 * opacity))
    actor_transform = Transform2D(0.0, Vector2(float(facing), 1.0) * scale_factor, 0.0, origin)
    if death_age >= 0.0:
        actor_transform = actor_transform * Transform2D(_ease(death_age / 0.85) * 1.48, Vector2.ZERO)
    actor_tint = Color(1.0, 1.0, 1.0, opacity)
    if hurt_age < 0.12:
        actor_tint = Color(1.65, 0.8, 0.66, opacity)
    var hip: Vector2 = pose["hip"]
    var body_angle: float = float(pose["body"])
    var spine: Vector2 = hip + Vector2(0, -4)
    var collar: Vector2 = spine + Vector2(0, -48).rotated(body_angle)
    var shoulder: Vector2 = spine + Vector2(14, -45).rotated(body_angle)
    var rear_shoulder: Vector2 = spine + Vector2(-12, -44).rotated(body_angle)
    _draw_cape(canvas, collar + Vector2(-5, -1))
    _leg(canvas, hip + Vector2(-4, 0), pose["rear_foot"], true)
    var offhand: Vector2 = _arm(canvas, rear_shoulder, pose["offhand"], true)
    _part(canvas, 4, rear_shoulder, Vector2(23, 23), Vector2(12, 8), -0.1, Color(0.68, 0.72, 0.8))
    _part(canvas, 12, hip + Vector2(1, -4), Vector2(19, 38), Vector2(9, 0), sin(phase) * 0.18 * run_blend + sin(time * 3.0) * 0.025)
    _leg(canvas, hip + Vector2(4, 0), pose["front_foot"], false)
    _part(canvas, 2, hip + Vector2(0, -9), Vector2(39, 29), Vector2(19, 6), body_angle * 0.4)
    _part(canvas, 14, hip + Vector2(-15, -3), Vector2(13, 15), Vector2(7, 3), sin(phase + 0.8) * 0.12 * run_blend)
    _part(canvas, 1, spine, Vector2(39, 55), Vector2(19, 55), body_angle)
    _part(canvas, 13, collar, Vector2(42, 22), Vector2(22, 4), body_angle)
    var neck: Vector2 = spine + Vector2(1, -53).rotated(body_angle)
    _part(canvas, 0, neck, Vector2(36, 43), Vector2(17, 39), -body_angle * 0.30 + sin(time * 2.5 - 0.3) * 0.012)
    var amulet: Vector2 = spine + Vector2(6, -36).rotated(body_angle)
    _part(canvas, 15, amulet, Vector2(7, 12), Vector2(3.5, 5), -body_angle + sin(time * 3.2) * 0.045)
    _glow(canvas, amulet, 12.0, Color(1.0, 0.47, 0.12), 0.055 + sin(time * 3.0) * 0.012)
    _draw_trail(canvas)
    var hand: Vector2 = _arm(canvas, shoulder, pose["hand"], false)
    _part(canvas, 4, shoulder, Vector2(28, 28), Vector2(14, 8), body_angle + 0.05)
    # The sword pivot is at the actual grip, not at the center of the texture.
    _part(canvas, 3, hand, Vector2(25, 82), Vector2(12.5, 71), float(pose["blade"]))
    if cast_age < CAST_DURATION:
        # Casting hand comes forward over the breastplate during the spell.
        if cast_age < 0.35:
            offhand = _arm(canvas, rear_shoulder, pose["offhand"], false)
        var energy: float = sin(clampf(cast_age / CAST_DURATION, 0.0, 1.0) * PI)
        var flame := offhand + Vector2(5, -7)
        _glow(canvas, flame, 28.0, Color(1.0, 0.29, 0.04), energy * 0.11)
        canvas.draw_set_transform_matrix(actor_transform)
        canvas.draw_arc(flame, 12.0 + energy * 6.0, time * 5.0, time * 5.0 + TAU * 0.8,
            24, Color(1.0, 0.67, 0.24, energy * opacity), 1.3, true)
        for i in range(5):
            var angle: float = float(i) * TAU / 5.0 + time * 6.0
            var spark: Vector2 = flame + Vector2(cos(angle), sin(angle)) * (8.0 + energy * 6.0)
            canvas.draw_circle(spark, 1.3, Color(1.0, 0.85, 0.46, energy * opacity))
        canvas.draw_circle(flame, 3.0 + energy * 3.0, Color(1.0, 0.88, 0.55, energy * opacity))
    if landing_age < 0.28 and death_age < 0.0:
        canvas.draw_set_transform_matrix(actor_transform)
        var dust_alpha: float = (1.0 - landing_age / 0.28) * 0.30 * opacity
        for i in range(8):
            var direction: float = -1.0 if i % 2 == 0 else 1.0
            var dust := Vector2(direction * (12.0 + landing_age * float(60 + i * 16)),
                -3.0 - sin(landing_age / 0.28 * PI) * float(2 + i % 3))
            canvas.draw_circle(dust, 1.2 + float(i % 3) * 0.7, Color(0.73, 0.66, 0.51, dust_alpha))
    canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
