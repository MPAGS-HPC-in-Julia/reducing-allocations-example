include("rendering/window.jl")
include("rendering/sphere_scene.jl")
include("physics.jl")
include("initial_conditions.jl")
using StaticArrays
using Profile
using PProf
using Profile.Allocs

mutable struct RenderFn{FAST,DIM,S,P,V,M,C}
    scene::S
    positions::P
    velocities::V
    masses::M
    G::Float64
    dt::Float64
    steps_per_frame::Int
    cache::C
    _use_fast::Val{FAST}
    _dim::Val{DIM}
end

function (fn::RenderFn{FAST})(window::MainWindow, dt) where {FAST}
    if (!window.is_paused)
        sub_dt = fn.dt / fn.steps_per_frame * dt
        for _ in 1:fn.steps_per_frame
            if FAST
                update_positions_fast!(fn.cache, fn.positions, fn.velocities, fn.masses, fn.G, sub_dt)

                # Swap the pointers on each cache
                fn.positions .= fn.cache.next_positions
                fn.velocities .= fn.cache.next_velocities
            else
                next_positions, next_velocities = update_positions(fn.positions, fn.velocities, fn.masses, fn.G, sub_dt)
                fn.positions .= next_positions
                fn.velocities .= next_velocities
            end
        end
        fn.scene.positions .= transpose(fn.positions)
    end
    draw_scene!(fn.scene, window.camera)
end

function main(; N=100, steps_per_frame=10, use_fast=false)
    positions, velocities, masses = initial_conditions(N, 1, 5)
    min_radius = 10.0
    max_radius = 4.0
    G = 5.0
    dt = 0.001 * 60

    cube_root_masses = masses .^ (1 / 3)
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

    update_cache = init_update_cache(N)
    # update_cache = nothing

    render_fn = RenderFn(scene, positions, velocities, masses, G, dt, steps_per_frame, update_cache, use_fast ? Val(true) : Val(false), Val(3))

    render_loop(render_fn, window)

    cleanup(scene)
    cleanup(window)
    nothing
end

main(; N=500, use_fast=true)
