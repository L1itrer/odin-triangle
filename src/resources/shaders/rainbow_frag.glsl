#version 450 core

in vec4 vertColor;
in vec2 texCoord;

uniform vec4 dtColor;
uniform sampler2D ourTexture;

out vec4 outColor;

void main()
{
  vec4 baseColor = vertColor;
  vec4 supColor = (dtColor / 2) + 0.5;
  outColor = texture(ourTexture, texCoord) * baseColor * supColor ;//mix(baseColor, dtColor, 0.2);//vec4(vertColor, 1.0);
}
