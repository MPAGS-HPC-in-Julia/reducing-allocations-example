
function draw_spheres(vao, indices, num_instances)
    glBindVertexArray(vao[])
    glDrawElementsInstanced(GL_TRIANGLES, length(indices), GL_UNSIGNED_INT, C_NULL, num_instances)
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

    glLineWidth(4.0f0)

    frame_limit = 0.02f0

    inv_scale = inv(60.0f0)
    for i in 1:length(graph_vertices)÷2-1
        t = graph_vertices[2i] * inv_scale
        if t > frame_limit
            glUniform3f(color_loc, 1.0, 0.0, 0.0)  # Red
        else
            glUniform3f(color_loc, 1.0, 1.0, 0.0)  # Yellow
        end
        glDrawArrays(GL_LINES, i - 1, 2)
    end

    glLineWidth(1.0f0)
end


function draw_text(buffer, vertices_store, text_program, text_vao, text_vbo, characters, text_projection, frame_tracker)
    glUseProgram(text_program)
    glActiveTexture(GL_TEXTURE0)
    glUniform1i(glGetUniformLocation(text_program, "text"), 0)

    render_text("0ms", vertices_store, characters, 10.0f0, 25.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])
    render_text("16ms", vertices_store, characters, 10.0f0, 100.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])

    max_ms = Int(round(maximum(frame_tracker.times) * 1000))
    
    # Empty the buffer
    empty!(buffer)
    write!(buffer, "Max Frame Time: ")
    write!(buffer, max_ms)
    write!(buffer, "ms")
    buf_text = get_string(buffer)
    render_text(buf_text, vertices_store, characters, 1600.0f0, 1050.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])

    avg_fps = calculate_average_fps(frame_tracker.times)
    if isnan(avg_fps)
        return
    end
    
    avg_fps = Int(round(avg_fps))
    empty!(buffer)
    write!(buffer, "Avg FPS: ")
    write!(buffer, avg_fps)
    buf_text = get_string(buffer)
    render_text(buf_text, vertices_store, characters, 1600.0f0, 1000.0f0, 0.5f0, text_projection, text_program, text_vao[], text_vbo[])
end