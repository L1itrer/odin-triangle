package app

import gl "vendor:OpenGL"
import "core:fmt"

Shader :: u32

@rodata
verticies := [?]f32 {
  -0.5, -0.5, 0.0,
  0.5, -0.5, 0.0,
  0.0, 0.5, 0.0
}

shaderProgram: Shader
gInitialized: bool = false
update_and_render :: proc(winHeight, winWidth: i32)
{
  if !gInitialized
  {
    init()
  }
  gl.ClearColor(0.1, 0.1, 0.1, 1.0)
  gl.Clear(u32(gl.GL_Enum.COLOR_BUFFER_BIT) | u32(gl.GL_Enum.DEPTH_BUFFER_BIT))
  gl.DrawArrays(cast(u32)gl.GL_Enum.TRIANGLES, 0, 3)
}

init :: proc()
{
  gInitialized = true
  // shader compilation
  vertexShaderSource := #load("../resources/shaders/vertex.glsl", cstring)
  fragmentShaderSource := #load("../resources/shaders/fragment.glsl", cstring)
  vertexShader, vok := shader_compile(vertexShaderSource, Shader_Kind.VERTEX)
  assert(vok)
  fragmentShader, fok := shader_compile(fragmentShaderSource, Shader_Kind.FRAGMENT)
  assert(fok)
  shaderProgram = gl.CreateProgram()
  gl.AttachShader(shaderProgram, vertexShader)
  gl.AttachShader(shaderProgram, fragmentShader)
  gl.LinkProgram(shaderProgram)
  gl.DeleteShader(vertexShader)
  gl.DeleteShader(fragmentShader)

  // vertex array creation
  vao: u32
  gl.GenVertexArrays(1, &vao)
  gl.BindVertexArray(vao)
  // buffer creation
  vbo: u32
  gl.GenBuffers(1, &vbo)
  // copy array into gpu memory
  gl.BindBuffer(cast(u32)gl.GL_Enum.ARRAY_BUFFER, vbo)
  gl.BufferData(cast(u32)gl.GL_Enum.ARRAY_BUFFER, size_of(verticies), &verticies, cast(u32)gl.GL_Enum.STATIC_DRAW)
  // describe the data format
  gl.VertexAttribPointer(0, 3, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
  gl.EnableVertexAttribArray(0)
  // enable the shader
  gl.UseProgram(shaderProgram)
}

Shader_Kind :: enum u64 {
  FRAGMENT = u64(gl.GL_Enum.FRAGMENT_SHADER),
  VERTEX = u64(gl.GL_Enum.VERTEX_SHADER),
}

shader_compile :: proc(source: cstring, shaderKind: Shader_Kind) -> (Shader, bool)
{
  source := source
  shader := gl.CreateShader(cast(u32)shaderKind)
  gl.ShaderSource(shader, 1, &source, nil)
  gl.CompileShader(shader)
  success: i32
  gl.GetShaderiv(shader, cast(u32)gl.GL_Enum.COMPILE_STATUS, &success)
  if !cast(bool)success
  {
    buffer := [1024]u8{}
    gl.GetShaderInfoLog(shader, cast(i32)size_of(buffer), nil, raw_data(buffer[:]))
    fmt.println(cstring(raw_data(buffer[:])))
    return shader, false
  }
  return shader, true
}


