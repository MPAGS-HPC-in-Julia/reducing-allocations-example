using ModernGL, GLFW, FreeType
using LinearAlgebra
using StaticArrays

# Shader sources
const vertex_shader = """
    #version 330 core
    layout (location = 0) in vec3 aPos;
    layout (location = 1) in vec3 aNormal;
    layout (location = 2) in vec3 aOffset;
    layout (location = 3) in vec3 aColor;
    layout (location = 4) in float aSize;
    
    uniform mat4 view;
    uniform mat4 projection;
    
    out vec3 Normal;
    out vec3 FragPos;
    out vec3 Color;
    
    void main()
    {
        FragPos = (aPos * aSize) + aOffset;
        Normal = aNormal;
        Color = aColor;
        gl_Position = projection * view * vec4(FragPos, 1.0);
    }
"""

const fragment_shader = """
    #version 330 core
    in vec3 Normal;
    in vec3 FragPos;
    in vec3 Color;
    
    uniform vec3 lightPos;
    
    out vec4 FragColor;
    
    void main()
    {
        vec3 norm = normalize(Normal);
        vec3 lightDir = normalize(lightPos - FragPos);
        float diff = max(dot(norm, lightDir), 0.0);
        vec3 diffuse = diff * Color;
        vec3 ambient = 0.1 * Color;
        FragColor = vec4(ambient + diffuse, 1.0);
    }
"""

# Add new shader constants at the top after existing shaders
const graph_vertex_shader = """
    #version 330 core
    layout (location = 0) in vec2 aPos;
    
    uniform float uHeight;
    
    void main()
    {
        // Move to bottom of screen and scale height
        gl_Position = vec4(aPos.x, (aPos.y * uHeight) - (1.0 - uHeight), 0.0, 1.0);
    }
"""

const graph_fragment_shader = """
    #version 330 core
    out vec4 FragColor;
    
    void main()
    {
        FragColor = vec4(1.0, 1.0, 0.0, 1.0);  // Yellow color
    }
"""

const text_vertex_shader = """
    #version 330 core
    layout (location = 0) in vec4 vertex; // <vec2 pos, vec2 tex>
    
    uniform vec2 uPosition;
    uniform vec2 uScale;
    
    out vec2 TexCoords;
    
    void main()
    {
        gl_Position = vec4(uPosition + (vertex.xy * uScale), 0.0, 1.0);
        TexCoords = vertex.zw;
    }
"""

const text_fragment_shader = """
    #version 330 core
    in vec2 TexCoords;
    out vec4 FragColor;
    
    uniform sampler2D text;
    uniform vec3 textColor;
    
    void main()
    {    
        vec4 sampled = vec4(1.0, 1.0, 1.0, texture(text, TexCoords).r);
        FragColor = vec4(textColor, 1.0) * sampled;
    }
"""

# Camera struct
mutable struct Camera
    position::SVector{3,Float32}
    front::SVector{3,Float32}
    up::SVector{3,Float32}
    yaw::Float32
    pitch::Float32
end

# Initialize camera
camera = Camera(
    SVector{3,Float32}(0, 0, 15),  # Move camera further out on z-axis
    SVector{3,Float32}(0, 0, -1),  # Keep looking towards center
    SVector{3,Float32}(0, 1, 0),
    -90.0f0,
    0.0f0
)

# Generate sphere vertices and indices
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

mutable struct MouseUpdate <: Function
    first_mouse::Bool
    last_x::Float32
    last_y::Float32
end

function (m::MouseUpdate)(window, xpos, ypos)
    if m.first_mouse
        m.last_x = xpos
        m.last_y = ypos
        m.first_mouse = false
    end

    xoffset = xpos - m.last_x
    yoffset = m.last_y - ypos
    m.last_x = xpos
    m.last_y = ypos

    sensitivity = 0.1f0
    xoffset *= sensitivity
    yoffset *= sensitivity

    camera.yaw += xoffset
    camera.pitch += yoffset

    camera.pitch = clamp(camera.pitch, -89.0f0, 89.0f0)

    front = SVector{3,Float32}(
        cos(deg2rad(camera.yaw)) * cos(deg2rad(camera.pitch)),
        sin(deg2rad(camera.pitch)),
        sin(deg2rad(camera.yaw)) * cos(deg2rad(camera.pitch))
    )
    camera.front = normalize(front)
end

# Add frame time tracking after camera initialization
const MAX_FRAMES = 200  # Number of frames to show in graph
mutable struct FrameTracker
    times::Vector{Float32}
    index::Int
    max_time::Float32
end

# Add new struct for character info
struct Character
    texture_id::GLuint
    size::Tuple{Float32, Float32}
    bearing::Tuple{Float32, Float32}
    advance::Float32
end

# Replace create_text_vertices with new text rendering system
function init_font()
    chars = Dict{Char, Character}()
    
    # Initialize FreeType
    library = Vector{FT_Library}(undef, 1)
    error = FT_Init_FreeType(library)
    if error != 0
        error_message = unsafe_string(FT_Error_String(error))
        @error "Failed to initialize FreeType: $error_message"
        return chars
    end
    
    # Load Consolas font - adjust path as needed
    face = Vector{FT_Face}(undef, 500000)
    error = FT_New_Face(library, "C:\\Windows\\Fonts\\consola.ttf", 0, face)
    if error != 0
        FT_Done_FreeType(library)
        error_message = unsafe_string(FT_Error_String(error))
        @error "Failed to load font: $error_message"
        return chars
    end

    FT_Set_Pixel_Sizes(face, 0, 48)
    
    # Disable byte-alignment restriction
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    
    # Load first 128 ASCII characters
    for c in Char(0):Char(127)
        # Load character glyph
        FT_Load_Char(face, c, FT_LOAD_RENDER)
        
        # Generate texture
        texture = GLuint(0)
        glGenTextures(1, Ref(texture))
        glBindTexture(GL_TEXTURE_2D, texture)
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RED,
            face.glyph.bitmap.width,
            face.glyph.bitmap.rows,
            0,
            GL_RED,
            GL_UNSIGNED_BYTE,
            face.glyph.bitmap.buffer
        )
        
        # Set texture options
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        
        # Store character
        chars[c] = Character(
            texture,
            (Float32(face.glyph.bitmap.width), Float32(face.glyph.bitmap.rows)),
            (Float32(face.glyph.bitmap_left), Float32(face.glyph.bitmap_top)),
            Float32(face.glyph.advance.x >> 6)
        )
    end
    
    FT_Done_Face(face)
    FT_Done_FreeType(library)
    
    return chars
end

function render_text(text::String, chars::Dict{Char,Character}, x::Float32, y::Float32, scale::Float32, vao::GLuint, vbo::GLuint)
    glBindVertexArray(vao)
    
    for c in text
        ch = chars[c]
        
        xpos = x + ch.bearing[1] * scale
        ypos = y - (ch.size[2] - ch.bearing[2]) * scale
        
        w = ch.size[1] * scale
        h = ch.size[2] * scale
        
        # Update VBO for each character
        vertices = Float32[
            xpos,     ypos + h,   0.0, 0.0,
            xpos,     ypos,       0.0, 1.0,
            xpos + w, ypos,       1.0, 1.0,
            xpos,     ypos + h,   0.0, 0.0,
            xpos + w, ypos,       1.0, 1.0,
            xpos + w, ypos + h,   1.0, 0.0
        ]
        
        # Render glyph texture over quad
        glBindTexture(GL_TEXTURE_2D, ch.texture_id)
        
        # Update content of VBO memory
        glBindBuffer(GL_ARRAY_BUFFER, vbo)
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertices), vertices)
        
        # Render quad
        glDrawArrays(GL_TRIANGLES, 0, 6)
        
        # Advance cursors for next glyph
        x += ch.advance * scale
    end
end

function main()
    # Initialize GLFW and create window
    GLFW.Init()
    window = GLFW.CreateWindow(1920, 1080, "Sphere Instancing")
    GLFW.MakeContextCurrent(window)

    # Create and compile shaders
    vertex_shader_id = GLuint(0)
    fragment_shader_id = GLuint(0)

    vertex_shader_id = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(vertex_shader_id, 1, Ptr{GLchar}[pointer(vertex_shader)], C_NULL)
    glCompileShader(vertex_shader_id)

    fragment_shader_id = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fragment_shader_id, 1, Ptr{GLchar}[pointer(fragment_shader)], C_NULL)
    glCompileShader(fragment_shader_id)

    program = glCreateProgram()
    glAttachShader(program, vertex_shader_id)
    glAttachShader(program, fragment_shader_id)
    glLinkProgram(program)

    # Add after shader program creation
    # Create graph shader program
    graph_vertex_shader_id = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(graph_vertex_shader_id, 1, Ptr{GLchar}[pointer(graph_vertex_shader)], C_NULL)
    glCompileShader(graph_vertex_shader_id)

    graph_fragment_shader_id = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(graph_fragment_shader_id, 1, Ptr{GLchar}[pointer(graph_fragment_shader)], C_NULL)
    glCompileShader(graph_fragment_shader_id)

    graph_program = glCreateProgram()
    glAttachShader(graph_program, graph_vertex_shader_id)
    glAttachShader(graph_program, graph_fragment_shader_id)
    glLinkProgram(graph_program)

    # Create text shader program
    text_vertex_shader_id = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(text_vertex_shader_id, 1, Ptr{GLchar}[pointer(text_vertex_shader)], C_NULL)
    glCompileShader(text_vertex_shader_id)

    text_fragment_shader_id = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(text_fragment_shader_id, 1, Ptr{GLchar}[pointer(text_fragment_shader)], C_NULL)
    glCompileShader(text_fragment_shader_id)

    text_program = glCreateProgram()
    glAttachShader(text_program, text_vertex_shader_id)
    glAttachShader(text_program, text_fragment_shader_id)
    glLinkProgram(text_program)

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

    # Initialize frame tracker
    frame_tracker = FrameTracker(zeros(Float32, MAX_FRAMES), 1, 0.0f0)

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
    num_instances = 10000
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
    mouse_callback = MouseUpdate(true, 400.0f0, 300.0f0)
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

    # Main loop
    while !GLFW.WindowShouldClose(window)
        frame_start = time()

        glClearColor(0.2f0, 0.3f0, 0.3f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        camera_speed = 0.05f0
        if GLFW.GetKey(window, GLFW.KEY_W) == GLFW.PRESS
            camera.position += camera_speed * camera.front
        end
        if GLFW.GetKey(window, GLFW.KEY_S) == GLFW.PRESS
            camera.position -= camera_speed * camera.front
        end
        if GLFW.GetKey(window, GLFW.KEY_A) == GLFW.PRESS
            camera.position -= normalize(cross(camera.front, camera.up)) * camera_speed
        end
        if GLFW.GetKey(window, GLFW.KEY_D) == GLFW.PRESS
            camera.position += normalize(cross(camera.front, camera.up)) * camera_speed
        end

        # Use shader program
        glUseProgram(program)

        # Set uniforms
        view = GLfloat[
            1 0 0 0;
            0 1 0 0;
            0 0 1 0;
            0 0 0 1
        ]
        target = camera.position + camera.front
        view = lookAt(camera.position, target, camera.up)

        projection = perspective(45.0f0, 800.0f0 / 600.0f0, 0.1f0, 100.0f0)

        view_loc = glGetUniformLocation(program, "view")
        proj_loc = glGetUniformLocation(program, "projection")
        light_pos_loc = glGetUniformLocation(program, "lightPos")

        glUniformMatrix4fv(view_loc, 1, GL_FALSE, view)
        glUniformMatrix4fv(proj_loc, 1, GL_FALSE, projection)
        glUniform3fv(light_pos_loc, 1, camera.position)

        # Draw spheres
        glBindVertexArray(vao[])
        glDrawElementsInstanced(GL_TRIANGLES, length(indices), GL_UNSIGNED_INT, C_NULL, num_instances)

        # After main rendering, draw frame time graph
        frame_time = Float32(time() - frame_start)
        frame_tracker.times[frame_tracker.index] = frame_time
        frame_tracker.max_time = max(frame_tracker.max_time, frame_time)
        frame_tracker.index = frame_tracker.index % MAX_FRAMES + 1
        
        # Generate graph vertices with newest frames on right
        graph_vertices = Float32[]
        current_idx = frame_tracker.index - 1
        if current_idx == 0
            current_idx = MAX_FRAMES
        end
        
        for i in 1:MAX_FRAMES
            # Map x from [-1,1] with newest frame at 1
            x = 2.0f0 * (MAX_FRAMES - i) / (MAX_FRAMES - 1) - 1.0f0
            idx = mod1(current_idx - (i-1), MAX_FRAMES)
            y = frame_tracker.times[idx] / frame_tracker.max_time
            push!(graph_vertices, x, y)
        end
        
        # Draw graph
        glUseProgram(graph_program)
        glBindVertexArray(graph_vao[])
        glBindBuffer(GL_ARRAY_BUFFER, graph_vbo[])
        glBufferData(GL_ARRAY_BUFFER, sizeof(graph_vertices), graph_vertices, GL_DYNAMIC_DRAW)
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, C_NULL)
        glEnableVertexAttribArray(0)
        
        height_loc = glGetUniformLocation(graph_program, "uHeight")
        glUniform1f(height_loc, 0.1f0)  # Graph takes up bottom 10% of screen
        
        glDrawArrays(GL_LINE_STRIP, 0, length(graph_vertices)÷2)
        
        # Draw scale markers
        glUseProgram(text_program)
        glActiveTexture(GL_TEXTURE0)
        glUniform1i(glGetUniformLocation(text_program, "text"), 0)
        
        # Draw "0ms" at bottom
        glUniform3f(glGetUniformLocation(text_program, "textColor"), 1.0, 1.0, 1.0)
        render_text("0ms", characters, -0.95f0, -0.95f0, 0.001f0, text_vao[], text_vbo[])
        
        # Draw max time marker
        max_ms = round(frame_tracker.max_time * 1000, digits=1)
        render_text("$(max_ms)ms", characters, -0.95f0, -0.85f0, 0.001f0, text_vao[], text_vbo[])

        # Show current FPS in window title
        GLFW.SetWindowTitle(window, "Sphere Instancing - FPS: $(round(1/frame_time, digits=1))")
        
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
    glDeleteProgram(graph_program)
    glDeleteVertexArrays(1, graph_vao)
    glDeleteBuffers(1, graph_vbo)

    glDeleteProgram(text_program)
    glDeleteVertexArrays(1, text_vao)
    glDeleteBuffers(1, text_vbo)

    # Clean up font textures
    for char in values(characters)
        glDeleteTextures(1, Ref(char.texture_id))
    end

    GLFW.DestroyWindow(window)
    GLFW.Terminate()
end

# Helper functions for camera
function lookAt(eye::SVector{3,Float32}, center::SVector{3,Float32}, up::SVector{3,Float32})
    f = normalize(center - eye)
    s = normalize(cross(f, up))
    u = cross(s, f)

    return Float32[
        s[1] s[2] s[3] -dot(s, eye);
        u[1] u[2] u[3] -dot(u, eye);
        -f[1] -f[2] -f[3] dot(f, eye);
        0.0 0.0 0.0 1.0
    ]
end

function perspective(fov::Float32, aspect::Float32, near::Float32, far::Float32)
    tanHalfFovy = tan(fov / 2.0f0)

    return Float32[
        1.0f0/(aspect*tanHalfFovy) 0.0f0 0.0f0 0.0f0;
        0.0f0 1.0f0/tanHalfFovy 0.0f0 0.0f0;
        0.0f0 0.0f0 -(far + near)/(far-near) -2.0f0*far*near/(far-near);
        0.0f0 0.0f0 -1.0f0 0.0f0
    ]
end

main()