mutable struct Camera
    position::SVector{3,Float32}
    front::SVector{3,Float32}
    up::SVector{3,Float32}
    yaw::Float32
    pitch::Float32
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

function ortho(left::Float32, right::Float32, bottom::Float32, top::Float32, near::Float32=-1.0f0, far::Float32=1.0f0)
    return Float32[
        2/(right-left) 0 0 -(right + left)/(right-left);
        0 2/(top-bottom) 0 -(top + bottom)/(top-bottom);
        0 0 -2/(far-near) -(far + near)/(far-near);
        0 0 0 1
    ]
end