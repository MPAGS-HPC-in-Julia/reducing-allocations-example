
include("rendering/rendering.jl")
include("rendering/sphere_scene.jl")

struct RenderFn{S}
    scene::S
end

function (fn::RenderFn)(window::MainWindow)
    # TODO: Update positions
    draw_scene!(fn.scene, window.camera)
end

function main()
    window = MainWindow(1920, 1080, "Sphere Rendering")
    N = 100
    positions = rand(-5.0f0:0.01f0:5.0f0, 3, N)
    radii = [rand(0.5f0:0.001f0:2.0f0) for _ in 1:N]
    scene = SphereScene(N, radii, positions)

    render_fn = RenderFn(scene)

    render_loop(render_fn, window)

    cleanup(scene)
    cleanup(window)
    nothing
end

main()