include("rendering/rendering.jl")
include("rendering/sphere_scene.jl")
include("physics.jl")
include("initial_conditions.jl")
using StaticArrays
using Profile
using PProf
using Profile.Allocs

struct RenderFn{S, P, V, M}
    scene::S
    positions::P
    velocities::V
    masses::M
    G::Float64
    dt::Float64
    steps_per_frame::Int
end

function (fn::RenderFn)(window::MainWindow)
    if (!window.is_paused)
        sub_dt = fn.dt / fn.steps_per_frame
        for _ in 1:fn.steps_per_frame
            next_positions, next_velocities = update_positions(fn.positions, fn.velocities, fn.masses, fn.G, sub_dt)
            fn.positions .= next_positions
            fn.velocities .= next_velocities
        end
        fn.scene.positions .= transpose(fn.positions)
    end
    draw_scene!(fn.scene, window.camera)
end

function main()
    N = 100
    positions, velocities, masses = initial_conditions(N, 1, 5)
    min_radius = 10.0
    max_radius = 4.0
    G = 5.0
    dt = 0.001
    steps_per_frame = 10
    cube_root_masses = masses .^ (1/3)    
    min_mass, max_mass = extrema(@views cube_root_masses[2:end])
    radii = Float32.((cube_root_masses .- min_mass) ./ (max_mass - min_mass) .* (max_radius - min_radius) .+ min_radius)
    
    radii[1] = 25.0
    colors = rand(Float32, 3, N)

    # Set first shape to yellow
    colors[1:2] .= 1.0
    colors[3] = 0

    gl_positions = Matrix{Float32}(transpose(positions))
    
    
    window = MainWindow(1920, 1080, "Sphere Rendering")
    scene = SphereScene(N, radii, gl_positions, colors)

    render_fn = RenderFn(scene, positions, velocities, masses, G, dt, steps_per_frame)
    
    render_loop(render_fn, window)

    cleanup(scene)
    cleanup(window)
    nothing
end

# main()
# Profile.Allocs.clear()
# Profile.Allocs.@profile sample_rate=1 main()
# # Save the profiler results to disk
# PProf.Allocs.save("profile.pb")
# PProf.Allocs.pprof()

