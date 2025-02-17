
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