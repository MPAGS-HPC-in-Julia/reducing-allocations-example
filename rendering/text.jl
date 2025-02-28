struct Character
    texture_id::GLuint
    size::Tuple{Float32, Float32}
    metrics::FontExtent{Float64}
end

function init_font()
    chars = Dict{Char,Character}()

    # Load font using FreeTypeAbstraction
    font_face = FTFont(abspath(joinpath(@__DIR__, "..", "data", "Roboto.ttf")))

    # Disable byte-alignment restriction
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)

    # Load first 128 ASCII characters
    for c in Char(32):Char(127)  # Starting from space character
        # Get character bitmap and metrics
        bitmap, metrics = renderface(font_face, c, 48)

        # Generate texture
        texture = Ref{GLuint}(0)
        glGenTextures(1, texture)
        glBindTexture(GL_TEXTURE_2D, texture[])

        width, height = size(bitmap)

        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RED,
            width,
            height,
            0,
            GL_RED,
            GL_UNSIGNED_BYTE,
            bitmap
        )

        # Set texture options
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

        # Store character
        chars[c] = Character(
            texture[],
            (width, height),
            metrics
        )
    end

    return chars
end


function render_text(text, vertices_store, chars::Dict{Char,Character}, x::Float32, y::Float32, scale::Float32, projection::Matrix{Float32}, text_program::GLuint, vao::GLuint, vbo::GLuint)
    glUseProgram(text_program)
    glUniformMatrix4fv(glGetUniformLocation(text_program, "projection"), 1, GL_FALSE, projection)
    glUniform3f(glGetUniformLocation(text_program, "textColor"), 1.0, 1.0, 1.0)
    glActiveTexture(GL_TEXTURE0)
    glBindVertexArray(vao)

    for c in text
        if c isa UInt8
            c = Char(c)
        end
        ch = get(chars, c, chars[' '])  # Use space if character not found

        xpos = x + ch.metrics.horizontal_bearing[1] * scale
        ypos = y - (ch.size[2] - ch.metrics.horizontal_bearing[2]) * scale

        w = ch.size[1] * scale
        h = ch.size[2] * scale

        # Update VBO for each character
        vertices_store .= @SVector[
            xpos, ypos+h, 0.0, 0.0,
            xpos, ypos, 0.0, 1.0,
            xpos+w, ypos, 1.0, 1.0,
            xpos, ypos+h, 0.0, 0.0,
            xpos+w, ypos, 1.0, 1.0,
            xpos+w, ypos+h, 1.0, 0.0
        ]

        # Render glyph texture over quad
        glBindTexture(GL_TEXTURE_2D, ch.texture_id)

        # Update content of VBO memory
        glBindBuffer(GL_ARRAY_BUFFER, vbo)
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertices_store), vertices_store)

        # Render quad
        glDrawArrays(GL_TRIANGLES, 0, 6)

        # Advance cursors for next glyph
        x += ch.metrics.advance[1] * scale
    end

    glBindVertexArray(0)
    glBindTexture(GL_TEXTURE_2D, 0)
end