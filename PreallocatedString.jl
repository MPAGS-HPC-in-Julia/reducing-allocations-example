mutable struct PreallocatedString
    buffer::Vector{UInt8}
    current_length::Int
    capacity::Int
end

function PreallocatedString(N)
    return PreallocatedString(Vector{UInt8}(undef, N), 0, N)
end

# Helper to write a string into the buffer
function write!(ps::PreallocatedString, s::AbstractString)
    len = length(s)
    # if ps.current_length + len > ps.capacity
    #     throw(ArgumentError("Buffer overflow: not enough space"))
    # end
    
    offset = ps.current_length
    for (i, c) in enumerate(s)
        ps.buffer[offset + i] = UInt8(c)
    end
    ps.current_length += len
    return ps
end


# Helper to write a string into the buffer
function write!(ps::PreallocatedString, c::Char)
    offset = ps.current_length
    ps.buffer[offset + 1] = UInt8(c)
    ps.current_length += 1
    return ps
end

# Helper to write an integer into the buffer
function write!(ps::PreallocatedString, n::Integer)
    if n == 0
        write!(ps, '0')
        return ps
    end
    
    # Handle negative numbers
    if n < 0
        write!(ps, '-')
        n = -n
    end
    
    # Find number of digits
    digits = n > 0 ? floor(Int, log10(n)) + 1 : 1
    
    # Write digits from right to left
    start_pos = ps.current_length + digits
    # if start_pos > length(ps.buffer)
    #     throw(ArgumentError("Buffer overflow: not enough space"))
    # end
    
    pos = start_pos
    while n > 0
        digit = n % 10
        ps.buffer[pos] = UInt8('0' + digit)
        n ÷= 10
        pos -= 1
    end
    
    ps.current_length = start_pos
    return ps
end

# Reset the buffer
function empty!(ps::PreallocatedString)
    ps.current_length = 0
    return ps
end

# Get the current content as a string
function get_string(ps::PreallocatedString)
    return view(ps.buffer, 1:ps.current_length)
end

# Interpolation helper
function format!(ps::PreallocatedString, args...)
    empty!(ps)
    for arg in args
        write!(ps, arg)
    end
    get_string(ps)
end
