package app

import gl "vendor:OpenGL"
import "core:fmt"

Shader :: u32

State :: struct{
  initialized: b32,
  vao1, vao2, vbo1, vbo2 : u32,
  shaderProgram: u32,
  ebo: u32
}

STATE_UPPER_BOUND :: (64 * 1024)

#assert(size_of(State) < STATE_UPPER_BOUND)

YTOP :: 0.5
YBOT :: -0.5

@rodata
verticies := [?]f32 {
  -0.5, YBOT, 0.0, // bottom left
  -0.25, YTOP, 0.0, // top left
   0.0, YBOT, 0.0, // bottom middle
   0.25, YTOP, 0.0, // right top
   0.5, YBOT, 0.0, // right top
}

@rodata
indecies := [?]u32 {
  0, 1, 2,
  2, 3, 4,
}

update_and_render :: proc(statePtr: rawptr)
{
  state : ^State = cast(^State)statePtr
  if !state.initialized
  {
    init(state)
  }
  render(state)
}

render :: proc(state: ^State)
{
  gl.ClearColor(0.1, 0.1, 0.1, 1.0)
  gl.Clear(u32(gl.GL_Enum.COLOR_BUFFER_BIT) | u32(gl.GL_Enum.DEPTH_BUFFER_BIT))
  gl.DrawElements(cast(u32)gl.GL_Enum.TRIANGLES, 6, cast(u32)gl.GL_Enum.UNSIGNED_INT, rawptr(uintptr(0)))
}

init :: proc(state: ^State)
{
  state.initialized = true
  // shader compilation
  vertexShaderSource := #load("../resources/shaders/vertex.glsl", cstring)
  fragmentShaderSource := #load("../resources/shaders/fragment.glsl", cstring)
  vertexShader, vok := shader_compile(vertexShaderSource, Shader_Kind.VERTEX)
  assert(vok)
  fragmentShader, fok := shader_compile(fragmentShaderSource, Shader_Kind.FRAGMENT)
  assert(fok)
  shaderProgram := gl.CreateProgram()
  gl.AttachShader(shaderProgram, vertexShader)
  gl.AttachShader(shaderProgram, fragmentShader)
  gl.LinkProgram(shaderProgram)
  gl.DeleteShader(vertexShader)
  gl.DeleteShader(fragmentShader)
  // enable the shader
  gl.UseProgram(shaderProgram)
  state.shaderProgram = shaderProgram

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
  // create element buffer object
  // it specifies the order in which to draw to verticies
  ebo: u32
  gl.GenBuffers(1, &ebo)
  gl.BindBuffer(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, ebo)
  gl.BufferData(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, size_of(indecies), &indecies, cast(u32)gl.GL_Enum.STATIC_DRAW)


  // describe the data format
  gl.VertexAttribPointer(0, 3, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
  gl.EnableVertexAttribArray(0)

  // usefull for debugging, shows just frames of the triangles
  //gl.PolygonMode(cast(u32)gl.GL_Enum.FRONT_AND_BACK, auto_cast gl.GL_Enum.LINE)
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


