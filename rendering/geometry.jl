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


function generate_graph_vertices(frame_tracker)
    graph_vertices = Float32[]
    current_idx = frame_tracker.index - 1
    if current_idx == 0
        current_idx = frame_tracker.time_horizon
    end

    for i in 1:frame_tracker.time_horizon
        x = 2.0f0 * (frame_tracker.time_horizon - i) / (frame_tracker.time_horizon - 1) - 1.0f0
        idx = mod1(current_idx - (i - 1), frame_tracker.time_horizon)
        y = frame_tracker.times[idx] / 0.060f0
        push!(graph_vertices, x, y)
    end
    return graph_vertices
end