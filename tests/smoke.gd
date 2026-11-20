extends SceneTree
## Exercise the title and gameplay, then allow the audio mixer to release streams.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    if packed == null:
        push_error("Main scene could not be loaded")
        quit(1)
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    for frame in range(10):
        await process_frame
    print("Smoke test: title loaded")
    scene._reset_run(false)
    for frame in range(10):
        await physics_frame
    print("Smoke test: gameplay started")
    scene.queue_free()
    await process_frame
    await create_timer(0.2).timeout
    await process_frame
    print("Smoke test: scene and audio released")
    quit(0)
