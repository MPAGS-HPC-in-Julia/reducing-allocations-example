using GLMakie

function crossproduct(a, b)
    return [a[2]*b[3] - a[3]*b[2], a[3]*b[1] - a[1]*b[3], a[1]*b[2] - a[2]*b[1]]
end

function initial_conditions(N, thickness, radius)
    sphere_min_radius = radius - thickness / 2
    sphere_max_radius = radius + thickness / 2
    # Generate random positions in a sphere of radius 
    radii = ((rand(N) .* (sphere_max_radius^3 - sphere_min_radius^3)) .+ sphere_min_radius^3).^(1/3)
    theta = acos.(1 .- 2*rand(N))
    phi = 2 * pi * rand(N)

    positions = hcat(
        radii .* sin.(theta) .* cos.(phi),
        radii .* sin.(theta) .* sin.(phi),
        radii .* cos.(theta)
    )
    up = [0, 0, 1]
    velocities = map(1:N) do i 
        direction = crossproduct(up, positions[i, :])
        direction ./= sqrt(sum(c->c^2, direction))
        return direction * (rand() * 2  + 5)
    end
    velocities = Matrix(transpose(hcat(velocities...)))

    masses = rand(N)
    return positions, velocities, masses
end
function force(positions, masses, G)
    # Positions: N x 3 matrix with x, y, z coordinates
    # Masses: N vector
    # G: Gravitational constant

    N = size(positions, 1)
    x = positions[:, 1]
    y = positions[:, 2]
    z = positions[:, 3]
    
    # Create a matrix of distances between particles
    dx = (x' .- x)
    dy = (y' .- y)
    dz = (z' .- z)
    
    r = sqrt.(dx.^2 + dy.^2 + dz.^2)
    r = max.(r, 1e-3) # Avoid division by zero
    
    F = G * (masses' .* masses) ./ (r.^2)
    # Set the diagonal to zero to avoid self-interaction
    for i in 1:N
        F[i, i] = 0
    end
    
    # Calculate force components for each pair of particles
    Fx = F .* dx ./ r
    Fy = F .* dy ./ r
    Fz = F .* dz ./ r

    # Calculate net force 
    Fx = sum(Fx, dims=2)
    Fy = sum(Fy, dims=2)
    Fz = sum(Fz, dims=2)
    
    F = hcat(Fx, Fy, Fz)
    # Create N x 3 force array with x, y, z components
    return F
end
function update_positions(positions, velocities, masses, G, dt)
    # Calculate next position based on 2nd Order Runge Kutta method
    k1v = dt * force(positions, masses, G)
    k1p = dt * velocities

    k2v = (dt/2) * force(positions + 0.5 * k1p, masses, G)
    k2p = (dt/2) * (velocities + 0.5 * k1v)
    
    k3v = (dt/2) * force(positions + 0.5 * k2p, masses, G)
    k3p = (dt/2) * (velocities + 0.5 * k2v)
    
    k4v = dt * force(positions + k3p, masses, G)
    k4p = dt * (velocities + k3v)

    next_velocities = velocities + (k1v + 2*k2v + 2*k3v + k4v) / 6
    next_positions = positions + (k1p + 2*k2p + 2*k3p + k4p) / 6

    return next_positions, next_velocities
end

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