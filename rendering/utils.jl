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

function update_frame_tracker(frame_tracker, frame_time)
    frame_tracker.times[frame_tracker.index] = frame_time
    frame_tracker.max_time = max(frame_tracker.max_time, frame_time)
    frame_tracker.index = frame_tracker.index % frame_tracker.time_horizon + 1
end