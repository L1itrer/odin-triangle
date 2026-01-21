#version 330 core

layout(location = 0) out vec4 fragColor;
in vec4 vertexColor;

void main() 
{
  fragColor = vertexColor;
}
