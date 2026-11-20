extends SceneTree
## Exercise animation transitions, attachment constraints and game event wiring.

const Hero = preload("res://scripts/Flamewarden.gd")
var failures: int = 0

func _check(value: bool, label: String) -> void:
    if not value:
        failures += 1
        push_error(label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var hero = Hero.new()
    for frame in range(240):
        hero.advance(1.0 / 60.0, 290.0, true, 0.0, "playing")
        var hip: Vector2 = hero.pose["hip"]
        for foot_name in ["rear_foot", "front_foot"]:
            var foot: Vector2 = hero.pose[foot_name]
            _check(foot.is_finite(), "Non-finite running foot")
            _check(hip.distance_to(foot) < 70.0, "Running leg exceeds its reach")
    _check(hero.state_name == "run", "Running did not blend in")
    var stopped_phase: float = hero.phase
    for frame in range(90):
        hero.advance(1.0 / 60.0, 0.0, true, 0.0, "playing")
    _check(hero.phase == stopped_phase, "Stationary feet kept cycling")
    _check(hero.state_name == "idle", "Running did not blend out")
    for frame in range(30):
        hero.advance(1.0 / 60.0, 160.0, false, -500.0, "playing")
    _check(hero.state_name == "jump", "Jump pose missing")
    for frame in range(30):
        hero.advance(1.0 / 60.0, 160.0, false, 500.0, "playing")
    _check(hero.state_name == "fall", "Falling pose missing")
    hero.advance(1.0 / 60.0, 0.0, true, 0.0, "playing")
    _check(hero.landing_age < 0.05 and hero.landing > 0.0, "Landing did not compress")
    for frame in range(90):
        hero.advance(1.0 / 60.0, 0.0, true, 0.0, "playing")
    _check(absf(hero.landing) < 0.02, "Landing spring did not settle")
    for variant in range(3):
        hero.slash()
        _check(hero.combo == variant, "Sword variations did not cycle")
        hero.advance(0.10, 0.0, true, 0.0, "playing")
        _check(hero.state_name == "slash", "Sword pose missing")
        _check(Vector2(hero.pose["hand"]).is_finite(), "Sword wrist is not finite")
    hero.reset()
    hero.cast()
    hero.advance(0.05, 0.0, true, 0.0, "playing")
    _check(hero.state_name == "cast", "Magic pose missing")
    var paused_time: float = hero.time
    var paused_cast: float = hero.cast_age
    hero.advance(0.5, 290.0, false, 700.0, "paused")
    _check(hero.time == paused_time and hero.cast_age == paused_cast, "Pause advanced animation")
    hero.hurt()
    hero.advance(0.05, 0.0, true, 0.0, "playing")
    _check(hero.state_name == "hurt", "Hit reaction missing")
    hero.die()
    for frame in range(90):
        hero.advance(1.0 / 60.0, 0.0, true, 0.0, "dead")
    _check(hero.state_name == "death" and hero.death_age > 0.85, "Death did not finish")
    hero.reset()
    _check(hero.death_age < 0.0 and hero.state_name == "idle", "Respawn retained death pose")
    for start in [Vector2.ZERO, Vector2(5, -66)]:
        for target in [start, start + Vector2(50, 50), start + Vector2(1, 200)]:
            var knee: Vector2 = hero._ik(start, target, 35.0, 33.0)
            _check(knee.is_finite() and absf(knee.distance_to(start) - 35.0) < 0.01,
                "IK failed at a coincident or unreachable target")
    var scene = load("res://scenes/Main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene._reset_run(false)
    scene._slash()
    _check(scene.hero_visual.sword_age == 0.0, "Game sword event not connected")
    scene._cast()
    _check(scene.hero_visual.cast_age == 0.0, "Game magic event not connected")
    scene._damage_player(200.0)
    _check(scene.game_state == "dead" and scene.hero_visual.death_age == 0.0, "Game death event not connected")
    scene._reset_run(false)
    _check(scene.hero_visual.death_age < 0.0 and scene.invulnerability == 0.0, "Game respawn did not reset visual state")
    scene.queue_free()
    await process_frame
    await create_timer(0.2).timeout
    print("Character checks completed; failures: ", failures)
    quit(1 if failures > 0 else 0)
