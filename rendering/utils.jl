mutable struct FrameTracker
    times::Vector{Float32}
    max_frames::Int
    index::Int
    max_time::Float32
end

function calculate_average_fps(frame_times)
    valid_frames = filter(t->t>0, frame_times)
    return length(valid_frames) / sum(valid_frames)
end