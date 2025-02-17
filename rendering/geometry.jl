function create_sphere(radius, segments)
    vertices = Vector{Float32}()
    indices = Vector{UInt32}()
    normals = Vector{Float32}()

    for i in 0:segments
        lat = π * (-0.5 + Float32(i) / segments)
        for j in 0:segments
            lon = 2 * π * Float32(j) / segments

            x = cos(lat) * cos(lon)
            y = sin(lat)
            z = cos(lat) * sin(lon)

            push!(vertices, radius * x, radius * y, radius * z)
            push!(normals, x, y, z)
        end
    end

    for i in 0:segments-1
        for j in 0:segments-1
            first = i * (segments + 1) + j
            second = first + segments + 1

            push!(indices, first, second, first + 1)
            push!(indices, second, second + 1, first + 1)
        end
    end

    return vertices, indices, normals
end