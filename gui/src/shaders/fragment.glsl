#version 330 core
in vec2 texCoord;
in vec4 vColor;
out vec4 FragColor;
uniform sampler2D atlas;
void main() {
    float a = texture(atlas, texCoord).r;
    FragColor = vec4(vColor.rgb, vColor.a * a);
}
