using ModernGL
using GLFW
using FreeTypeAbstraction
using LinearAlgebra
using StaticArrays

# Import the necessary functions & structs from the other files
include("shaders.jl")
include("camera.jl")
include("geometry.jl")
include("text.jl")
include("utils.jl")
include("drawing.jl")
include("../PreallocatedString.jl")

function create_graph_buffers()
    # Create graph VAO and VBO
    graph_vao = Ref{GLuint}()
    graph_vbo = Ref{GLuint}()
    glGenVertexArrays(1, graph_vao)
    glGenBuffers(1, graph_vbo)

    return graph_vao, graph_vbo
end

function create_text_buffers()
    text_vao = Ref{GLuint}()
    text_vbo = Ref{GLuint}()
    glGenVertexArrays(1, text_vao)
    glGenBuffers(1, text_vbo)
    glBindVertexArray(text_vao[])
    glBindBuffer(GL_ARRAY_BUFFER, text_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(Float32) * 6 * 4, C_NULL, GL_DYNAMIC_DRAW)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, C_NULL)
    return text_vao, text_vbo
end

mutable struct MainWindow
    window::GLFW.Window
    camera::Camera
    graph_shader::Shader
    text_shader::Shader
    graph_vao::Ref{GLuint}
    graph_vbo::Ref{GLuint}
    text_vao::Ref{GLuint}
    text_vbo::Ref{GLuint}
    time_horizon::Int
    frame_tracker::FrameTracker
    target_fps::Int
    frame_time::Float32
    mouse_callback::MouseUpdate
    characters::Dict{Char,Character}
    text_projection::Matrix{Float32}
    is_paused::Bool
end

function MainWindow(width::Integer, height::Integer, title::String, target_fps::Union{Integer, Nothing} = nothing, vsync = true)
    GLFW.Init()
    
    # Set up fullscreen mode while maintaining resolution
    primary_monitor = GLFW.GetPrimaryMonitor()
    video_mode = GLFW.GetVideoMode(primary_monitor)
    
    # Use monitor refresh rate if target_fps is not specified
    actual_target_fps = isnothing(target_fps) ? video_mode.refreshrate : target_fps
    
    # Center the window on screen
    x_pos = (video_mode.width - width) ÷ 2
    y_pos = (video_mode.height - height) ÷ 2
    
    GLFW.WindowHint(GLFW.DECORATED, false)  # Remove window decorations
    window = GLFW.CreateWindow(width, height, title)
    GLFW.SetWindowPos(window, x_pos, y_pos)
    GLFW.MakeContextCurrent(window)
    
    # Set vysnc on window
    vsync && GLFW.SwapInterval(1)
    vsync || GLFW.SwapInterval(0)
    
    camera = Camera()
    graph_shader = Shader(GRAPH_VERTEX_SHADER, GRAPH_FRAGMENT_SHADER)
    text_shader = Shader(TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)

    graph_vao, graph_vbo = create_graph_buffers()
    text_vao, text_vbo = create_text_buffers()

    time_horizon = 60 * 5
    frame_tracker = FrameTracker(zeros(Float32, time_horizon), time_horizon, 1, 0.0f0)

    # Fix target_fps assignment (remove shadowing)
    frame_time = 1.0f0 / actual_target_fps

    mouse_callback = MouseUpdate(camera, true, Float32(width / 2), Float32(height / 2))
    GLFW.SetCursorPosCallback(window, mouse_callback)
    GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_DISABLED)

    characters = init_font()
    text_projection = ortho(0.0f0, Float32(width), 0.0f0, Float32(height))

    # Enable depth testing for 3D rendering
    glEnable(GL_DEPTH_TEST)

    # Enable blending for text rendering
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    return MainWindow(window, camera, graph_shader, text_shader,
        graph_vao, graph_vbo, text_vao, text_vbo,
        time_horizon, frame_tracker, actual_target_fps, frame_time,
        mouse_callback, characters, text_projection, true)
end

function cleanup(window::MainWindow)
    # Add to cleanup
    glDeleteProgram(window.graph_shader.program)
    glDeleteVertexArrays(1, window.graph_vao)
    glDeleteBuffers(1, window.graph_vbo)

    glDeleteProgram(window.text_shader.program)
    glDeleteVertexArrays(1, window.text_vao)
    glDeleteBuffers(1, window.text_vbo)

    # Clean up font textures
    for char in values(window.characters)
        glDeleteTextures(1, Ref(char.texture_id))
    end

    GLFW.DestroyWindow(window.window)
    GLFW.Terminate()
end
function render_loop(update_fn::F, window::MainWindow) where {F}
    # Preallocate buffers to reduce allocations
    graph_vertices_buffer = zeros(Float32, 2 * window.time_horizon)
    string_buffer = PreallocatedString(100)
    vertices_store = Vector{Float32}(undef, 6*4);
    last_pressed = false
    last_frame = time()
    while !GLFW.WindowShouldClose(window.window)
        frame_start = time()

        glClearColor(0.1f0, 0.1f0, 0.1f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        handle_input(window.window, window.camera, 0.05f0)

        if GLFW.GetKey(window.window, GLFW.KEY_SPACE) == GLFW.PRESS
            last_pressed = true
        else
            if last_pressed
                window.is_paused = !window.is_paused
            end
            last_pressed = false
        end
        
        # Draw call here
        t = time()
        dt = t - last_frame
        last_frame = t
        update_fn(window, dt)

        generate_graph_vertices!(graph_vertices_buffer, window.frame_tracker)
        draw_graph(window.graph_shader.program, window.graph_vao[], window.graph_vbo[], graph_vertices_buffer)

        draw_text(string_buffer, vertices_store, window.text_shader.program, window.text_vao[], window.text_vbo[], window.characters, window.text_projection, window.frame_tracker)

        GLFW.SwapBuffers(window.window)
        GLFW.PollEvents()

        frame_time = Float32(time() - frame_start)
        update_frame_tracker(window.frame_tracker, frame_time)
    end
end