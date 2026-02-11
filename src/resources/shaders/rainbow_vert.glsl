#version 450 core

layout(location = 0) in vec3 vPos;
layout(location = 1) in vec3 vCol;
layout(location = 2) in vec2 vTex;

out vec4 vertColor;
out vec2 texCoord;
uniform vec2 offset;

void main()
{
  vec4 posOut = vec4(vPos.xy + offset, vPos.z, 1.0);
  gl_Position = posOut;
  vertColor = vec4(vCol, 1.0);
  texCoord = vTex;
}
