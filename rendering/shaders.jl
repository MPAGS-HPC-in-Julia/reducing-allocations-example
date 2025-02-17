
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
        gl_Position = vec4(aPos.x, (aPos.y * uHeight) - (1.0 - uHeight), 0.0, 1.0);
    }
"""

const graph_fragment_shader = """
    #version 330 core
    out vec4 FragColor;
    
    uniform vec3 uColor;
    
    void main()
    {
        FragColor = vec4(uColor, 1.0);
    }
"""

const text_vertex_shader = """
    #version 330 core
    layout (location = 0) in vec4 vertex; // <vec2 pos, vec2 tex>
    out vec2 TexCoords;
    uniform mat4 projection;

    void main()
    {
        gl_Position = projection * vec4(vertex.xy, 0.0, 1.0);
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