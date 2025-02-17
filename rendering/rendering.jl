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


# Main window loop
function main(width::Integer, height::Integer, title::String)
    camera = Camera()
    # Initialize GLFW and create window
    GLFW.Init()
    window = GLFW.CreateWindow(width, height, title)
    GLFW.MakeContextCurrent(window)

    main_shader = Shader(MAIN_VERTEX_SHADER, MAIN_FRAGMENT_SHADER)
    graph_shader = Shader(GRAPH_VERTEX_SHADER, GRAPH_FRAGMENT_SHADER)
    text_shader = Shader(TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)

    # Create graph VAO and VBO
    graph_vao = Ref{GLuint}()
    graph_vbo = Ref{GLuint}()
    glGenVertexArrays(1, graph_vao)
    glGenBuffers(1, graph_vbo)

    # Create text VAO and VBO
    text_vao = Ref{GLuint}()
    text_vbo = Ref{GLuint}()
    glGenVertexArrays(1, text_vao)
    glGenBuffers(1, text_vbo)
    glBindVertexArray(text_vao[])
    glBindBuffer(GL_ARRAY_BUFFER, text_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(Float32) * 6 * 4, C_NULL, GL_DYNAMIC_DRAW)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, C_NULL)

    time_horizon = 60 * 5; # 5 seconds
    # Initialize frame tracker
    frame_tracker = FrameTracker(zeros(Float32, time_horizon), time_horizon, 1, 0.0f0)

    # Generate sphere mesh
    vertices, indices, normals = create_sphere(0.02f0, 16)  # increased from 0.02f0

    # Create VAO and VBOs
    vao = Ref{GLuint}()
    vbo = Ref{GLuint}()
    ebo = Ref{GLuint}()
    instance_vbo = Ref{GLuint}()

    glGenVertexArrays(1, vao)
    glGenBuffers(1, vbo)
    glGenBuffers(1, ebo)
    glGenBuffers(1, instance_vbo)

    glBindVertexArray(vao[])

    # Vertex attributes
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    vertex_data = Float32[]
    for i in 1:length(vertices)÷3
        # Vertex position
        push!(vertex_data, vertices[3i-2], vertices[3i-1], vertices[3i])
        # Normal
        push!(vertex_data, normals[3i-2], normals[3i-1], normals[3i])
    end
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STATIC_DRAW)

    # Position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(0)

    # Normal attribute
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), Ptr{Cvoid}(3 * sizeof(Float32)))
    glEnableVertexAttribArray(1)

    # Instance data
    num_instances = 100
    offsets = [SVector{3,Float32}(
        rand(-5.0f0:0.01f0:5.0f0),
        rand(-5.0f0:0.01f0:5.0f0),
        rand(-5.0f0:0.01f0:5.0f0)
    ) for _ in 1:num_instances]

    colors = [SVector{3,Float32}(rand(), rand(), rand()) for _ in 1:num_instances]
    sizes = [rand(0.5f0:0.001f0:2.0f0) for _ in 1:num_instances]  # modified size range

    glBindBuffer(GL_ARRAY_BUFFER, instance_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(offsets), reshape(reinterpret(Float32, offsets), :), GL_STATIC_DRAW)

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(2)
    glVertexAttribDivisor(2, 1)

    # Create and set up color buffer
    color_vbo = Ref{GLuint}()
    glGenBuffers(1, color_vbo)
    glBindBuffer(GL_ARRAY_BUFFER, color_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), reshape(reinterpret(Float32, colors), :), GL_STATIC_DRAW)
    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(3)
    glVertexAttribDivisor(3, 1)

    # Create and set up size buffer
    size_vbo = Ref{GLuint}()
    glGenBuffers(1, size_vbo)
    glBindBuffer(GL_ARRAY_BUFFER, size_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(sizes), sizes, GL_STATIC_DRAW)
    glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(4)
    glVertexAttribDivisor(4, 1)

    # Element buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

    # Enable depth testing
    glEnable(GL_DEPTH_TEST)

    # Camera movement variables
    mouse_callback = MouseUpdate(camera, true, 400.0f0, 300.0f0)
    GLFW.SetCursorPosCallback(window, mouse_callback)
    GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_DISABLED)

    # Add frame timing definition
    target_fps = 60
    frame_time = 1 / target_fps

    # Initialize font
    characters = init_font()

    # Configure VAO/VBO for texture quads
    text_vao = Ref{GLuint}()
    text_vbo = Ref{GLuint}()
    glGenVertexArrays(1, text_vao)
    glGenBuffers(1, text_vbo)
    glBindVertexArray(text_vao[])
    glBindBuffer(GL_ARRAY_BUFFER, text_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(Float32) * 6 * 4, C_NULL, GL_DYNAMIC_DRAW)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, C_NULL)

    # Enable blending for text rendering
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    # Create orthographic projection for text rendering
    text_projection = ortho(0.0f0, Float32(1920), 0.0f0, Float32(1080))

    while !GLFW.WindowShouldClose(window)
        frame_start = time()

        glClearColor(0.2f0, 0.3f0, 0.3f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        handle_input(window, camera, 0.05f0)

        glUseProgram(main_shader.program)
        update_camera(camera, main_shader.program)
        draw_spheres(vao, indices, num_instances)

        frame_time = Float32(time() - frame_start)
        update_frame_tracker(frame_tracker, frame_time)

        graph_vertices = generate_graph_vertices(frame_tracker)
        draw_graph(graph_shader.program, graph_vao[], graph_vbo[], graph_vertices)

        draw_text(text_shader.program, text_vao[], text_vbo[], characters, text_projection, frame_tracker)

        GLFW.SwapBuffers(window)
        GLFW.PollEvents()

        # Control frame rate
        elapsed = time() - frame_start
        if elapsed < frame_time
            sleep(frame_time - elapsed)
        end
    end

    # Cleanup
    glDeleteVertexArrays(1, vao)
    glDeleteBuffers(1, vbo)
    glDeleteBuffers(1, ebo)
    glDeleteBuffers(1, instance_vbo)
    glDeleteBuffers(1, color_vbo)
    glDeleteBuffers(1, size_vbo)

    # Add to cleanup
    glDeleteProgram(graph_shader.program)
    glDeleteVertexArrays(1, graph_vao)
    glDeleteBuffers(1, graph_vbo)

    glDeleteProgram(text_shader.program)
    glDeleteVertexArrays(1, text_vao)
    glDeleteBuffers(1, text_vbo)

    # Clean up font textures
    for char in values(characters)
        glDeleteTextures(1, Ref(char.texture_id))
    end

    GLFW.DestroyWindow(window)
    GLFW.Terminate()
end

function draw_spheres(vao, indices, num_instances)
    glBindVertexArray(vao[])
    glDrawElementsInstanced(GL_TRIANGLES, length(indices), GL_UNSIGNED_INT, C_NULL, num_instances)
end

function update_frame_tracker(frame_tracker, frame_time)
    frame_tracker.times[frame_tracker.index] = frame_time
    frame_tracker.max_time = max(frame_tracker.max_time, frame_time)
    frame_tracker.index = frame_tracker.index % frame_tracker.time_horizon + 1
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

function draw_graph(graph_program, graph_vao, graph_vbo, graph_vertices)
    glUseProgram(graph_program)
    glBindVertexArray(graph_vao[])
    glBindBuffer(GL_ARRAY_BUFFER, graph_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(graph_vertices), graph_vertices, GL_DYNAMIC_DRAW)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(0)

    height_loc = glGetUniformLocation(graph_program, "uHeight")
    glUniform1f(height_loc, 0.1f0)  # Graph takes up bottom 10% of screen

    color_loc = glGetUniformLocation(graph_program, "uColor")

    glLineWidth(2.0f0)

    frame_limit = 20.0f0
    for i in 1:length(graph_vertices)÷2-1
        if graph_vertices[2i] > frame_limit / 60.0f0
            glUniform3f(color_loc, 1.0, 0.0, 0.0)  # Red
        else
            glUniform3f(color_loc, 1.0, 1.0, 0.0)  # Yellow
        end
        glDrawArrays(GL_LINES, i - 1, 2)
    end

    glLineWidth(1.0f0)
end

function draw_text(text_program, text_vao, text_vbo, characters, text_projection, frame_tracker)
    glUseProgram(text_program)
    glActiveTexture(GL_TEXTURE0)
    glUniform1i(glGetUniformLocation(text_program, "text"), 0)

    render_text("0ms", characters, 10.0f0, 25.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])
    render_text("60ms", characters, 10.0f0, 130.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])

    max_ms = round(maximum(frame_tracker.times) * 1000, digits=1)
    render_text("Max: $(max_ms)ms", characters, 10.0f0, 155.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])

    avg_fps = round(calculate_average_fps(frame_tracker.times), digits=1)
    fps_text = "Avg FPS: $avg_fps"
    render_text(fps_text, characters, 1700.0f0, 1050.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])
end