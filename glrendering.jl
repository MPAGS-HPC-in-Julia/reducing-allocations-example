include("rendering/rendering.jl")
include("rendering/sphere_scene.jl")
include("physics.jl")
using StaticArrays

struct RenderFn{S, P, V, M}
    scene::S
    positions::P
    velocities::V
    masses::M
    G::Float64
    dt::Float64
end

function (fn::RenderFn)(window::MainWindow)
    next_positions, next_velocities = update_positions(fn.positions, fn.velocities, fn.masses, fn.G, fn.dt)
    fn.positions .= next_positions
    fn.velocities .= next_velocities
    fn.scene.positions .= transpose(fn.positions)
    draw_scene!(fn.scene, window.camera)
end

function main()
    N = 100
    positions, velocities, masses = initial_conditions(N, 1, 5)
    min_radius = 10.0
    max_radius = 4.0
    G = 20.0
    dt = 0.01
    cube_root_masses = masses .^ (1/3)    
    
    radii = Float32.((cube_root_masses .- minimum(cube_root_masses)) ./ (maximum(cube_root_masses) - minimum(cube_root_masses)) .* (max_radius - min_radius) .+ min_radius)
    gl_positions = Matrix{Float32}(transpose(positions))
    
    
    window = MainWindow(1920, 1080, "Sphere Rendering")
    scene = SphereScene(N, radii, gl_positions)

    render_fn = RenderFn(scene, positions, velocities, masses, G, dt)
    
    render_loop(render_fn, window)

    cleanup(scene)
    cleanup(window)
    nothing
end

main()