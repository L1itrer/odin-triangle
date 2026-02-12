#version 450 core

layout(location = 0) in vec3 vPos;
layout(location = 1) in vec3 vCol;
layout(location = 2) in vec2 vTex;

out vec4 vertColor;
out vec2 texCoord;

uniform mat4 transform;

void main()
{
  gl_Position = transform * vec4(vPos, 1.0);
  vertColor = vec4(vCol, 1.0);
  texCoord = vTex;
}
