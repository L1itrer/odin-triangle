#version 450 core

layout(location = 0) in vec3 vPos;
layout(location = 1) in vec3 vCol;

out vec3 vertColor;

void main()
{
  gl_Position = vec4(vPos.xyz, 1.0);
  vertColor = vCol;
}
