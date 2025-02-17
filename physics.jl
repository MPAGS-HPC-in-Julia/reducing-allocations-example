using BenchmarkTools
using StaticArrays

mutable struct UpdateCache
    k1v::Matrix{Float64}
    k1p::Matrix{Float64}
    k2v::Matrix{Float64}
    k2p::Matrix{Float64}
    k3v::Matrix{Float64}
    k3p::Matrix{Float64}
    k4v::Matrix{Float64}
    k4p::Matrix{Float64}
    next_positions::Matrix{Float64}
    next_velocities::Matrix{Float64}
    acceleration::Matrix{Float64}
end

function UpdateCache(N, d, T=Float64)
    return UpdateCache(
        (zeros(T, N, d) for _ in 1:11)...
    )
end

function acceleration_fast!(acceleration, positions, masses, G, ::Val{D}) where {D}
    N, _ = size(positions)
    acceleration .= 0
    @inbounds for i in 1:N 
        xi = SVector((positions[i, k] for k in 1:D)...)
        mi = masses[i]
        for j in (i+1):N
            xj = SVector((positions[j, k] for k in 1:D)...)
            mj = masses[j]
            r = 0
            for k in 1:D
                r += (xi[k] - xj[k])^2
            end
            r = sqrt(r)
            scale = G * inv(r*r*r)
            for k in 1:D
                ak = scale * (xj[k] - xi[k])
                acceleration[i, k] += ak * mj
                acceleration[j, k] -= ak * mi
            end
        end
    end
    return acceleration
end

function update_positions_fast!(cache, positions, velocities, masses, G, dt, dim)
    # Calculate next position based on Runge Kutta method
    cache.k1v .= dt .* acceleration_fast!(cache.acceleration, positions, masses, G, dim)
    cache.k1p .= dt .* velocities

    cache.next_positions .= @. positions + 0.5 * cache.k1p
    cache.k2v .= (dt/2) .* acceleration_fast!(cache.acceleration, cache.next_positions, masses, G, dim)
    cache.k2p .= (dt/2) .* (velocities .+ 0.5 .* cache.k1v)

    cache.next_positions .= @. positions + 0.5 * cache.k2p    
    cache.k3v .= (dt/2) .* acceleration_fast!(cache.acceleration, cache.next_positions, masses, G, dim)
    cache.k3p .= (dt/2) .* (velocities .+ 0.5 .* cache.k2v)
    
    cache.next_positions .= @. positions + cache.k3p
    cache.k4v .= dt .* acceleration_fast!(cache.acceleration, cache.next_positions, masses, G, dim)
    cache.k4p .= dt .* (velocities .+ cache.k3v)

    cache.next_velocities .= @. velocities + (cache.k1v + 2*cache.k2v + 2*cache.k3v + cache.k4v) / 6
    cache.next_positions .= @. positions + (cache.k1p + 2*cache.k2p + 2*cache.k3p + cache.k4p) / 6

    return cache.next_positions, cache.next_velocities
end


using Test
function test_optimisations()
    N = 100
    D = 3
    positions, velocities, masses = initial_conditions(N, 1, 5);
    G = 5.0
    dt = 0.01

    cache = UpdateCache(N, D, Float64)
    dimVal = Val(D)
    next_positions, next_velocities = update_positions(positions, velocities, masses, G, dt)
    next_positions_fast, next_velocities_fast = update_positions_fast!(cache, positions, velocities, masses, G, dt, dimVal)

    @testset "Positions" begin
        @test next_positions ≈ next_positions_fast
    end
    @testset "Velocities" begin
        @test next_velocities ≈ next_velocities_fast
    end
    nothing

    # original_allocations = @allocations update_positions(positions, velocities, masses, G, dt);
    # new_allocations = @allocations update_positions_fast!(cache, positions, velocities, masses, G, dt);

    # println("Original allocations: ", original_allocations)
    # println("New allocations: ", new_allocations)

    println("Old benchmark:")
    display(@benchmark update_positions($positions, $velocities, $masses, $G, $dt))
    println("New benchmark:")
    display(@benchmark update_positions_fast!($cache, $positions, $velocities, $masses, $G, $dt, $dimVal))
end

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
