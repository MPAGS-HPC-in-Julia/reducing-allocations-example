using GLMakie
include("physics.jl")

function animate!(centers, positions, velocities, masses, G, dt)
    N = length(masses)
    next_positions, next_velocities = update_positions(positions, velocities, masses, G, dt)
    centers_array = centers[]
    for j in 1:N
        centers_array[j] = Point3f(positions[j, 1], positions[j, 2], positions[j, 3])
    end
    positions .= next_positions
    velocities .= next_velocities
    centers[] = centers_array # Re-trigger the observable
end

function main(; max_t = 10, N = 100, G = 10, min_radius = 0.02, max_radius = 0.1, fps_print_freq = 5, max_fps = 240)
    positions, velocities, masses = initial_conditions(N, 2, 10)
    # Calculate radius based on the masses
    cube_root_masses = masses .^ (1/3)    
    radii = (cube_root_masses .- minimum(cube_root_masses)) ./ (maximum(cube_root_masses) - minimum(cube_root_masses)) .* (max_radius - min_radius) .+ min_radius

    sphere = Sphere(Point3f(0, 0, 0), 1f0)
    centers = Observable([Point3f(positions[i, 1], positions[i, 2], positions[i, 3]) for i in 1:N])
    colors = [RGBf(rand(), rand(), rand()) for _ in 1:N]
    
    scene = Scene(size = (800, 600))
    cam3d!(scene)
    meshscatter!(scene, centers, color = colors, markersize=radii, overdraw=true, shading=FastShading)
    center!(scene)

    task = @async begin
        last_time = time_ns()
        first_time = last_time
        max_time = max_t # seconds
        last_frames = 0
        last_fps_time = time_ns()
        nframes = 0
        min_frame_time = 1/max_fps
        while true
            nframes += 1
            current_time = time_ns()
            delta_time = (current_time - last_time) / 1e9
            animate!(centers, positions, velocities, masses, G, delta_time / 10)
            frame_time = (current_time - last_time) / 1e9
            if current_time - last_fps_time > 1e9 * fps_print_freq
                # Clear the console
                print("\e[H\e[2J")
                elapsed_frames = nframes - last_frames
                fps = elapsed_frames / ((current_time - last_fps_time) / 1e9)
                last_fps_time = current_time
                last_frames = nframes
                println("FPS: ", fps)
            end
            if current_time - first_time > 1e9 * max_time
                println("Finished")
                break
            end
            if frame_time < min_frame_time
                sleep(min_frame_time - frame_time)
            end
            # TODO: Use last_time to estimate time steps
            last_time = current_time
        end
    end

    display(scene)

    return task
end

function cancel(task)
    Base.throwto(task, InterruptException())
end