
struct SphereScene
    shader::Shader
    vao::Ref{GLuint}
    vbo::Ref{GLuint}
    ebo::Ref{GLuint}
    instance_vbo::Ref{GLuint}
    color_vbo::Ref{GLuint}
    size_vbo::Ref{GLuint}
    indices ::Ref{GLuint}
    N::Int
    radii::Vector{Float32}
    positions::Matrix{Float32}
end

function draw_scene!(scene::SphereScene, camera)
    glUseProgram(scene.shader.program)
    update_camera(camera, scene.shader.program)
    draw_spheres(scene.vao, scene.indices, scene.N)
end

function cleanup(scene::SphereScene)
    cleanup(scene.shader)
    glDeleteVertexArrays(1, scene.vao)
    glDeleteBuffers(1, scene.vbo)
    glDeleteBuffers(1, scene.ebo)
    glDeleteBuffers(1, scene.instance_vbo)
    glDeleteBuffers(1, scene.color_vbo)
    glDeleteBuffers(1, scene.size_vbo)

    nothing
end

function SphereScene(N::Int, radii::Vector{Float32}, positions::Matrix{Float32})
    main_shader = Shader(MAIN_VERTEX_SHADER, MAIN_FRAGMENT_SHADER)
    return SphereScene(main_shader, generate_sphere_buffers(N, radii, positions)..., N, radii, positions)
end

function generate_sphere_buffers(num_instances::Int, radii::Vector{Float32}, positions::Matrix{Float32})
    vertices, indices, normals = create_sphere(0.02f0, 16)

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
        push!(vertex_data, vertices[3i-2], vertices[3i-1], vertices[3i])
        push!(vertex_data, normals[3i-2], normals[3i-1], normals[3i])
    end
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STATIC_DRAW)

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(0)

    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), Ptr{Cvoid}(3 * sizeof(Float32)))
    glEnableVertexAttribArray(1)

    # Instance data

    colors = [SVector{3,Float32}(rand(), rand(), rand()) for _ in 1:num_instances]

    glBindBuffer(GL_ARRAY_BUFFER, instance_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(positions), reshape(reinterpret(Float32, positions), :), GL_STATIC_DRAW)

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(2)
    glVertexAttribDivisor(2, 1)

    # Color buffer
    color_vbo = Ref{GLuint}()
    glGenBuffers(1, color_vbo)
    glBindBuffer(GL_ARRAY_BUFFER, color_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), reshape(reinterpret(Float32, colors), :), GL_STATIC_DRAW)
    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(3)
    glVertexAttribDivisor(3, 1)

    # Size buffer
    size_vbo = Ref{GLuint}()
    glGenBuffers(1, size_vbo)
    glBindBuffer(GL_ARRAY_BUFFER, size_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(radii), radii, GL_STATIC_DRAW)
    glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(4)
    glVertexAttribDivisor(4, 1)

    # Element buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

    # Enable depth testing
    glEnable(GL_DEPTH_TEST)

    return vao, vbo, ebo, instance_vbo, color_vbo, size_vbo, indices
end