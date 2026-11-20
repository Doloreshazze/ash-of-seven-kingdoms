extends SceneTree
## Real-renderer contact sheet. Run with xvfb, not Godot's headless dummy renderer.

const Hero = preload("res://scripts/Flamewarden.gd")

class ReviewBoard extends Node2D:
    var actors: Array = []
    var labels: Array[String] = ["I. VIGIL", "II. RUN", "III. ASCENT", "IV. DESCENT",
        "V. CLEAVE", "VI. RISING CUT", "VII. DRAGONFIRE", "VIII. IMPACT", "IX. FALLEN"]

    func _draw() -> void:
        draw_rect(Rect2(0, 0, 1536, 1100), Color("10171f"))
        draw_string(ThemeDB.fallback_font, Vector2(42, 48), "FLAMEWARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 31, Color("e6c48a"))
        draw_string(ThemeDB.fallback_font, Vector2(42, 75), "ASH OF THE SEVEN KINGDOMS  /  PAINTED CHARACTER STUDY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8296a5"))
        for index in range(actors.size()):
            var col: int = index % 3
            var row: int = index / 3
            var x: float = float(col) * 512.0
            var floor_y: float = 370.0 + float(row) * 329.0
            draw_rect(Rect2(x + 22, floor_y - 280, 468, 316), Color("17232c"))
            draw_line(Vector2(x + 46, floor_y + 5), Vector2(x + 466, floor_y + 5), Color("35434c"), 1.0)
            draw_arc(Vector2(x + 244, floor_y - 126), 117.0, PI, TAU, 60, Color("2a3741"), 1.0, true)
            var actor = actors[index]
            actor.draw_actor(self, Vector2(x + 232.0, floor_y), floor_y, 1, 1.0, 1.48)
            draw_string(ThemeDB.fallback_font, Vector2(x + 46, floor_y + 27), labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d0b582"))

class MotionStage extends Node2D:
    var actor = Hero.new()
    var segment: int = -1
    var label: String = ""
    var lift: float = 0.0

    func sample(t: float, dt: float) -> void:
        var next: int = 0
        var speed: float = 0.0
        var grounded: bool = true
        var vertical: float = 0.0
        lift = 0.0
        label = "VIGIL / BREATHING"
        if t >= 5.6:
            next = 9
            label = "FALL / SETTLE"
        elif t >= 5.2:
            next = 8
            label = "IMPACT / RECOVER"
        elif t >= 4.6:
            next = 7
            label = "DRAGONFIRE"
        elif t >= 4.1:
            next = 6
            label = "SWORD / THRUST"
        elif t >= 3.6:
            next = 5
            label = "SWORD / RISING CUT"
        elif t >= 3.1:
            next = 4
            label = "SWORD / CLEAVE"
        elif t >= 2.75:
            next = 3
            label = "LANDING / WEIGHT"
        elif t >= 1.95:
            next = 2
            label = "JUMP / DESCENT"
            var flight: float = t - 1.95
            grounded = false
            vertical = -300.0 + 750.0 * flight
            lift = (-300.0 * flight + 375.0 * flight * flight) * 1.65
        elif t >= 0.65:
            next = 1
            label = "RUN / CLOTH INERTIA"
            speed = 290.0
        if next != segment:
            segment = next
            if segment in [4, 5, 6]:
                actor.slash()
            elif segment == 7:
                actor.cast()
            elif segment == 8:
                actor.hurt()
            elif segment == 9:
                actor.die()
        actor.advance(dt, speed, grounded, vertical, "dead" if segment == 9 else "playing")

    func _draw() -> void:
        draw_rect(Rect2(0, 0, 768, 512), Color("10171f"))
        draw_string(ThemeDB.fallback_font, Vector2(34, 41), "FLAMEWARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e6c48a"))
        draw_string(ThemeDB.fallback_font, Vector2(35, 64), "ASH OF THE SEVEN KINGDOMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8296a5"))
        draw_arc(Vector2(365, 283), 147, PI, TAU, 70, Color("2a3741"), 1.0, true)
        draw_line(Vector2(34, 454), Vector2(734, 454), Color("35434c"), 1.0)
        actor.draw_actor(self, Vector2(347, 450 + lift), 450, 1, 1.0, 1.65)
        draw_string(ThemeDB.fallback_font, Vector2(35, 490), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d0b582"))

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1536, 1100)
    root.content_scale_size = Vector2i(1536, 1100)
    var board := ReviewBoard.new()
    for index in range(9):
        var actor = Hero.new()
        for frame in range(60):
            var speed: float = 290.0 if index == 1 else 0.0
            var air: bool = index == 2 or index == 3
            actor.advance(1.0 / 60.0, speed, not air, -480.0 if index == 2 else (500.0 if index == 3 else 0.0), "playing")
        if index == 1:
            actor.phase = 1.1
            actor._build_pose()
        elif index == 4 or index == 5:
            actor.slash()
            if index == 5:
                actor.slash()
            for frame in range(10):
                actor.advance(1.0 / 60.0, 0.0, true, 0.0, "playing")
        elif index == 6:
            actor.cast()
            for frame in range(11):
                actor.advance(1.0 / 60.0, 0.0, true, 0.0, "playing")
        elif index == 7:
            actor.hurt()
            for frame in range(9):
                actor.advance(1.0 / 60.0, 0.0, true, 0.0, "playing")
        elif index == 8:
            actor.die()
            for frame in range(60):
                actor.advance(1.0 / 60.0, 0.0, true, 0.0, "dead")
        board.actors.append(actor)
    root.add_child(board)
    board.queue_redraw()
    for frame in range(4):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image.is_empty():
        push_error("Character review renderer produced an empty image")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute("res://build")
    image.save_png("res://build/Flamewarden-review.png")
    # A bounded JPEG preview in the log permits remote art inspection as well.
    var encoded: String = Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.88))
    for offset in range(0, encoded.length(), 6000):
        print("CHARACTER_PREVIEW:", encoded.substr(offset, 6000))
    print("Character review saved: build/Flamewarden-review.png")
    root.remove_child(board)
    board.free()
    root.size = Vector2i(768, 512)
    root.content_scale_size = Vector2i(768, 512)
    var stage := MotionStage.new()
    root.add_child(stage)
    DirAccess.make_dir_recursive_absolute("res://build/hero-motion")
    for frame in range(168):
        stage.sample(float(frame) / 24.0, 1.0 / 24.0)
        stage.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var motion_image: Image = root.get_texture().get_image()
        motion_image.save_png("res://build/hero-motion/frame-%03d.png" % frame)
    print("Character motion captured: 168 frames at 24 fps")
    quit(0)
