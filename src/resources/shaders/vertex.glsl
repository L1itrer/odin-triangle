#version 330 core

layout(location = 0) in vec3 position;
out vec4 vertexColor;

void main()
{
  gl_Position = vec4(position.xyz, 1.0);
  vertexColor = vec4(0.2, 0.8, 0.2, 1.0);
}
