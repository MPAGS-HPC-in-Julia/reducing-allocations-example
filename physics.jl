using BenchmarkTools
using Test
using StaticArrays
using LoopVectorization
include("initial_conditions.jl")

function test_benchmark()
    N = 100
    positions, velocities, masses = initial_conditions(N, 1, 5)
    G = 5.0
    dt = 0.01

    update_cache = init_update_cache(N)
    D = size(positions, 2)
    dim = Val(D)
    original_next_pos, original_next_vel = update_positions(positions, velocities, masses, G, dt)
    optimised_next_pos, optmised_next_vel = update_positions_fast!(update_cache, positions, velocities, masses, G, dt, dim)
    @testset "Positions" begin
        @test original_next_pos ≈ optimised_next_pos
    end
    @testset "Velocities" begin
        @test original_next_vel ≈ optmised_next_vel
    end
    display(@benchmark update_positions($positions, $velocities, $masses, $G, $dt))
    display(@benchmark update_positions_fast!($update_cache, $positions, $velocities, $masses, $G, $dt, $dim))
end


function init_update_cache(N, T=Float64)
    return (;
        k1v=Matrix{T}(undef, N, 3),
        k1p=Matrix{T}(undef, N, 3),
        k2v=Matrix{T}(undef, N, 3),
        k2p=Matrix{T}(undef, N, 3),
        k3v=Matrix{T}(undef, N, 3),
        k3p=Matrix{T}(undef, N, 3),
        k4v=Matrix{T}(undef, N, 3),
        k4p=Matrix{T}(undef, N, 3),
        next_positions=Matrix{T}(undef, N, 3),
        accelerations=Matrix{T}(undef, N, 3),
        next_velocities=Matrix{T}(undef, N, 3),
    )
end

function update_positions_fast!(cache, positions, velocities, masses, G, dt, dim)
    # Calculate next position based on Runge Kutta method
    cache.k1v .= dt .* acceleration_fast!(cache.accelerations, positions, masses, G, dim)
    cache.k1p .= dt .* velocities

    cache.next_positions .= @. positions .+ 0.5 .* cache.k1p
    cache.k2v .= (dt / 2) .* acceleration_fast!(cache.accelerations, cache.next_positions, masses, G, dim)
    cache.k2p .= @. (dt / 2) * (velocities + 0.5 * cache.k1v)

    cache.next_positions .= @. positions + 0.5 * cache.k2p
    cache.k3v .= (dt / 2) .* acceleration_fast!(cache.accelerations, cache.next_positions, masses, G, dim)
    cache.k3p .= @. (dt / 2) * (velocities + 0.5 * cache.k2v)

    cache.next_positions .= @. positions + cache.k3p
    cache.k4v .= dt .* acceleration_fast!(cache.accelerations, cache.next_positions, masses, G, dim)
    cache.k4p .= @. dt * (velocities + cache.k3v)

    cache.next_velocities .= @. velocities + (cache.k1v + 2 * cache.k2v + 2 * cache.k3v + cache.k4v) / 6
    cache.next_positions .= @. positions + (cache.k1p + 2 * cache.k2p + 2 * cache.k3p + cache.k4p) / 6

    return cache.next_positions, cache.next_velocities
end
square(x) = x*x
function acceleration_fast!(accelerations, positions, masses, G, ::Val{D}) where {D}
    N, _ = size(positions)
    accelerations .= 0
    @inbounds for i in 1:N
        p_i = SVector(positions[i, 1], positions[i, 2], positions[i, 3])
        m_i = masses[i]
        a_i = SVector(0.0, 0.0, 0.0)
        a_ji = SVector(0.0, 0.0, 0.0)
        @turbo warn_check_args=false for j in i+1:N
            # (3, ) Vector
            p_j = SVector(positions[j, 1], positions[j, 2], positions[j, 3])
            
            # (3,) Vector
            dp_ij = (p_j .- p_i)
            # Scalars
            r_ij = sqrt(sum(square, dp_ij))
            # (3,) Vector
            scaling = G / r_ij^3

            scaled_dp_ij = scaling .* dp_ij
            a_i += masses[j] .* scaled_dp_ij

            a_ji = -m_i .* scaled_dp_ij

            for k in 1:D
                accelerations[j, k] += a_ji[k]
            end
        end
        for k in 1:D
            accelerations[i, k] += a_i[k]
        end
    end
    return accelerations
end

function update_positions(positions, velocities, masses, G, dt)
    # Calculate next position based on Runge Kutta method
    k1v = dt * acceleration(positions, masses, G)
    k1p = dt * velocities

    k2v = (dt / 2) * acceleration(positions + 0.5 * k1p, masses, G)
    k2p = (dt / 2) * (velocities + 0.5 * k1v)

    k3v = (dt / 2) * acceleration(positions + 0.5 * k2p, masses, G)
    k3p = (dt / 2) * (velocities + 0.5 * k2v)

    k4v = dt * acceleration(positions + k3p, masses, G)
    k4p = dt * (velocities + k3v)

    next_velocities = velocities + (k1v + 2 * k2v + 2 * k3v + k4v) / 6
    next_positions = positions + (k1p + 2 * k2p + 2 * k3p + k4p) / 6

    return next_positions, next_velocities
end

function acceleration(positions, masses, G)
    # Positions: N x 3 matrix with x, y, z coordinates
    # Masses: N vector
    # G: Gravitational constant

    N = size(positions, 1)
    # Vector (N)
    x = positions[:, 1]
    y = positions[:, 2]
    z = positions[:, 3]

    # Create a matrix of distances between particles
    # Matrix (NxN)
    dx = (x' .- x)
    dy = (y' .- y)
    dz = (z' .- z)

    r = sqrt.(dx .^ 2 + dy .^ 2 + dz .^ 2)
    r = max.(r, 1e-3) # Avoid division by zero

    F = G * (masses .* masses') ./ (r .^ 2)
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
