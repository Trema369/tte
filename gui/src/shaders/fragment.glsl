#version 330 core
in vec2 texCoord;
uniform sampler2D atlas;
uniform vec4 textColor;
out vec4 FragColor;
void main() {
    float a = texture(atlas, texCoord).r;
    FragColor = vec4(textColor.rgb, textColor.a * a);
}
