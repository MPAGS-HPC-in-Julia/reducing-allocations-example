mutable struct Camera
    position::SVector{3,Float32}
    front::SVector{3,Float32}
    up::SVector{3,Float32}
    yaw::Float32
    pitch::Float32
end

function Camera() # Default camera
    camera = Camera(
        SVector{3,Float32}(0, 0, 15),  # Move camera further out on z-axis
        SVector{3,Float32}(0, 0, -1),  # Keep looking towards center
        SVector{3,Float32}(0, 1, 0),
        -90.0f0,
        0.0f0
    )
    return camera
end

mutable struct MouseUpdate <: Function
    camera::Camera
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

    camera = m.camera

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

function lookAt(eye::SVector{3,Float32}, center::SVector{3,Float32}, up::SVector{3,Float32})
    f = normalize(center - eye)
    s = normalize(cross(f, up))
    u = cross(s, f)

    dot1 = -dot(s, eye)
    dot2 = -dot(u, eye)
    dot3 = dot(f, eye)

    return @SMatrix Float32[
        s[1] s[2] s[3] dot1;
        u[1] u[2] u[3] dot2;
        -f[1] -f[2] -f[3] dot3;
        0.0 0.0 0.0 1.0
    ]
end

function perspective(fov::Float32, aspect::Float32, near::Float32, far::Float32)
    tanHalfFovy = tan(fov / 2.0f0)

    return @SMatrix Float32[
        1.0f0/(aspect*tanHalfFovy) 0.0f0 0.0f0 0.0f0;
        0.0f0 1.0f0/tanHalfFovy 0.0f0 0.0f0;
        0.0f0 0.0f0 -(far + near)/(far-near) -2.0f0*far*near/(far-near);
        0.0f0 0.0f0 -1.0f0 0.0f0
    ]
end

function ortho(left::Float32, right::Float32, bottom::Float32, top::Float32, near::Float32=-1.0f0, far::Float32=1.0f0)
    return @SMatrix Float32[
        2/(right-left) 0 0 -(right + left)/(right-left);
        0 2/(top-bottom) 0 -(top + bottom)/(top-bottom);
        0 0 -2/(far-near) -(far + near)/(far-near);
        0 0 0 1
    ]
end


function handle_input(window, camera, camera_speed)
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
end

function update_camera(camera, program)
    v = @SMatrix Float32[
        1 0 0 0;
        0 1 0 0;
        0 0 1 0;
        0 0 0 1
    ]
    target = camera.position + camera.front
    v = lookAt(camera.position, target, camera.up)

    projection = perspective(45.0f0, 800.0f0 / 600.0f0, 0.1f0, 100.0f0)

    view_loc = glGetUniformLocation(program, "view")
    proj_loc = glGetUniformLocation(program, "projection")
    light_pos_loc = glGetUniformLocation(program, "lightPos")

    glUniformMatrix4fv(view_loc, 1, GL_FALSE, v)
    glUniformMatrix4fv(proj_loc, 1, GL_FALSE, projection)
    glUniform3fv(light_pos_loc, 1, camera.position)
end