mutable struct FrameTracker
    times::Vector{Float32}
    time_horizon::Int
    index::Int
    max_time::Float32
end



function calculate_average_fps(frame_tracker::FrameTracker, max_frames=frame_tracker.time_horizon)
    frame_times = frame_tracker.times
    total_frame_time = 0.0
    nvalid_times = 0

    for k in 0:(frame_tracker.time_horizon-1)
        i = (frame_tracker.index - k + frame_tracker.time_horizon - 1) % frame_tracker.time_horizon + 1
        t = frame_times[i]
        if t > 0
            nvalid_times += 1
            total_frame_time += t
        end
        if nvalid_times >= max_frames
            break
        end
    end
    return nvalid_times / total_frame_time
end
function calculate_max_frametime(frame_tracker::FrameTracker, max_frames=frame_tracker.time_horizon)
    frame_times = frame_tracker.times
    nvalid_times = 0
    max_time = 0
    for k in 0:(frame_tracker.time_horizon-1)
        i = (frame_tracker.index - k + frame_tracker.time_horizon - 1) % frame_tracker.time_horizon + 1
        t = frame_times[i]
        if t > 0
            nvalid_times += 1
            max_time = max(max_time, t)
        end
        if nvalid_times >= max_frames
            break
        end
    end
    return max_time
end

function update_frame_tracker(frame_tracker, frame_time)
    frame_tracker.times[frame_tracker.index] = frame_time
    frame_tracker.max_time = max(frame_tracker.max_time, frame_time)
    frame_tracker.index = frame_tracker.index % frame_tracker.time_horizon + 1
end