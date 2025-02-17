using ModernGL

struct SphereScene
    num_instances::Int
    radii::Vector{Float32}
    positions::Matrix{Float32}
    vao::GLuint
    vbo::GLuint
    ebo::GLuint
    instance_vbo::GLuint
    color_vbo::GLuint
    size_vbo::GLuint
    num_indices::Int
    shader::Shader
end

function SphereScene(num_instances::Int, radii::Vector{Float32}, positions::Matrix{Float32})
    # Create shader
    shader = Shader(MAIN_VERTEX_SHADER, MAIN_FRAGMENT_SHADER)

    # Generate sphere mesh
    vertices, indices, normals = create_sphere(0.02f0, 16)

    # Create VAO and VBOs
    vao = Ref{GLuint}()
    vbo = Ref{GLuint}()
    ebo = Ref{GLuint}()
    instance_vbo = Ref{GLuint}()
    color_vbo = Ref{GLuint}()
    size_vbo = Ref{GLuint}()

    glGenVertexArrays(1, vao)
    glGenBuffers(1, vbo)
    glGenBuffers(1, ebo)
    glGenBuffers(1, instance_vbo)
    glGenBuffers(1, color_vbo)
    glGenBuffers(1, size_vbo)

    glBindVertexArray(vao[])

    # Vertex attributes
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    vertex_data = Float32[]
    for i in 1:length(vertices)÷3
        push!(vertex_data, vertices[3i-2], vertices[3i-1], vertices[3i])
        push!(vertex_data, normals[3i-2], normals[3i-1], normals[3i])
    end
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STATIC_DRAW)

    # Position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), C_NULL)
    glEnableVertexAttribArray(0)

    # Normal attribute
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), Ptr{Cvoid}(3 * sizeof(Float32)))
    glEnableVertexAttribArray(1)

    # Instance position data
    glBindBuffer(GL_ARRAY_BUFFER, instance_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(positions), positions, GL_DYNAMIC_DRAW)
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(2)
    glVertexAttribDivisor(2, 1)

    # Colors
    colors = [SVector{3,Float32}(rand(), rand(), rand()) for _ in 1:num_instances]
    glBindBuffer(GL_ARRAY_BUFFER, color_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), reshape(reinterpret(Float32, colors), :), GL_STATIC_DRAW)
    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(3)
    glVertexAttribDivisor(3, 1)

    # Sizes/radii
    glBindBuffer(GL_ARRAY_BUFFER, size_vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(radii), radii, GL_STATIC_DRAW)
    glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, 0, C_NULL)
    glEnableVertexAttribArray(4)
    glVertexAttribDivisor(4, 1)

    # Element buffer
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

    SphereScene(
        num_instances,
        radii,
        positions,
        vao[],
        vbo[],
        ebo[],
        instance_vbo[],
        color_vbo[],
        size_vbo[],
        length(indices),
        shader
    )
end

function draw_scene!(scene::SphereScene, camera::Camera)
    # Update instance positions buffer with new data
    glBindBuffer(GL_ARRAY_BUFFER, scene.instance_vbo)
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(scene.positions), scene.positions)
    
    glUseProgram(scene.shader.program)
    update_camera(camera, scene.shader.program)

    glBindVertexArray(scene.vao)
    glDrawElementsInstanced(GL_TRIANGLES, scene.num_indices, GL_UNSIGNED_INT, C_NULL, scene.num_instances)
end

function cleanup(scene::SphereScene)
    glDeleteProgram(scene.shader.program)
    glDeleteVertexArrays(1, Ref{GLuint}(scene.vao))
    glDeleteBuffers(1, Ref{GLuint}(scene.vbo))
    glDeleteBuffers(1, Ref{GLuint}(scene.ebo))
    glDeleteBuffers(1, Ref{GLuint}(scene.instance_vbo))
    glDeleteBuffers(1, Ref{GLuint}(scene.color_vbo))
    glDeleteBuffers(1, Ref{GLuint}(scene.size_vbo))
end