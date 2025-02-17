mutable struct FrameTracker
    times::Vector{Float32}
    time_horizon::Int
    index::Int
    max_time::Float32
end

function calculate_average_fps(frame_times)
    total_frame_time = 0.0
    nvalid_times = 0
    for t in frame_times
        if t > 0
            nvalid_times += 1
            total_frame_time += t
        end
    end
    return nvalid_times / total_frame_time
end