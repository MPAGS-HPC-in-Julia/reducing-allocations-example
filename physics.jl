function acceleration(positions, masses, G)
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
    
    F = G * (masses .* masses') ./ (r.^2)
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
    
    # Use F=ma to calculate the acceleration
    A = hcat(Fx, Fy, Fz) ./ masses
    return A
end


function update_positions(positions, velocities, masses, G, dt)
    # Calculate next position based on Runge Kutta method
    k1v = dt * acceleration(positions, masses, G)
    k1p = dt * velocities

    k2v = (dt/2) * acceleration(positions + 0.5 * k1p, masses, G)
    k2p = (dt/2) * (velocities + 0.5 * k1v)
    
    k3v = (dt/2) * acceleration(positions + 0.5 * k2p, masses, G)
    k3p = (dt/2) * (velocities + 0.5 * k2v)
    
    k4v = dt * acceleration(positions + k3p, masses, G)
    k4p = dt * (velocities + k3v)

    next_velocities = velocities + (k1v + 2*k2v + 2*k3v + k4v) / 6
    next_positions = positions + (k1p + 2*k2p + 2*k3p + k4p) / 6

    return next_positions, next_velocities
end
