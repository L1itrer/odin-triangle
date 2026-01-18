package app

import gl "vendor:OpenGL"
import "core:fmt"

Shader :: u32

State :: struct{
  initialized: b32,
  vao: [2]u32,
  vbo: [2]u32,
  ebo: [2]u32,
  shaderProgram: u32,
  alterShaderProgram: u32
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
indecies0 := [?]u32 {
  0, 1, 2,
}

indecies1 := [?]u32 {
  2, 3, 4
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
  gl.UseProgram(state.shaderProgram)
  gl.BindVertexArray(state.vao[0])
  gl.BindBuffer(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, state.ebo[0])
  gl.DrawElements(cast(u32)gl.GL_Enum.TRIANGLES, 3, cast(u32)gl.GL_Enum.UNSIGNED_INT, rawptr(uintptr(0)))
  gl.UseProgram(state.alterShaderProgram)
  gl.BindVertexArray(state.vao[1])
  gl.BindBuffer(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, state.ebo[1])
  gl.DrawElements(cast(u32)gl.GL_Enum.TRIANGLES, 3, cast(u32)gl.GL_Enum.UNSIGNED_INT, rawptr(uintptr(0)))
}

init :: proc(state: ^State)
{
  state.initialized = true
  // shader compilation
  vertexShaderSource := #load("../resources/shaders/vertex.glsl", cstring)
  fragmentShaderSource := #load("../resources/shaders/fragment.glsl", cstring)
  fragalterShaderSource := #load("../resources/shaders/fragalter.glsl", cstring)
  shaderProgram, ok := shader_create(vertexShaderSource, fragmentShaderSource)
  assert(ok)
  alterShaderProgram, aok := shader_create(vertexShaderSource, fragalterShaderSource)
  assert(aok)

  // enable the shader
  gl.UseProgram(shaderProgram)
  state.shaderProgram = shaderProgram
  state.alterShaderProgram = alterShaderProgram

  // vertex array creation
  vao: [2]u32
  gl.GenVertexArrays(2, raw_data(vao[:]))
  // buffer creation
  vbo: [2]u32
  gl.GenBuffers(2, raw_data(vbo[:]))

  ebo: [2]u32
  gl.GenBuffers(2, raw_data(ebo[:]))
  // copy array into gpu memory
  gl.BindVertexArray(vao[0])
  gl.BindBuffer(cast(u32)gl.GL_Enum.ARRAY_BUFFER, vbo[0])
  gl.BufferData(cast(u32)gl.GL_Enum.ARRAY_BUFFER, size_of(verticies), &verticies, cast(u32)gl.GL_Enum.STATIC_DRAW)
  gl.BindBuffer(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, ebo[0])
  gl.BufferData(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, size_of(indecies0), &indecies0, cast(u32)gl.GL_Enum.STATIC_DRAW)
  gl.VertexAttribPointer(0, 3, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
  gl.EnableVertexAttribArray(0)

  gl.BindVertexArray(vao[1])
  gl.BindBuffer(cast(u32)gl.GL_Enum.ARRAY_BUFFER, vbo[1])
  gl.BufferData(cast(u32)gl.GL_Enum.ARRAY_BUFFER, size_of(verticies), &verticies, cast(u32)gl.GL_Enum.STATIC_DRAW)
  gl.BindBuffer(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, ebo[1])
  gl.BufferData(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, size_of(indecies1), &indecies1, cast(u32)gl.GL_Enum.STATIC_DRAW)
  gl.VertexAttribPointer(0, 3, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
  gl.EnableVertexAttribArray(0)

  state.ebo = ebo
  state.vbo = vbo
  state.vao = vao



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

shader_create :: proc(vertexSource: cstring, fragmentSource: cstring) -> (shader: Shader, ok: bool)
{
  shader = gl.CreateProgram()
  vertexShader, vok := shader_compile(vertexSource, Shader_Kind.VERTEX)
  fragmentShader, fok := shader_compile(fragmentSource, Shader_Kind.FRAGMENT)
  if vok && fok
  {
    gl.AttachShader(shader, vertexShader)
    gl.AttachShader(shader, fragmentShader)
    gl.LinkProgram(shader)
  }
  if vok do gl.DeleteShader(vertexShader)
  if fok do gl.DeleteShader(fragmentShader)
  if !vok || !fok
  {
    gl.DeleteProgram(shader)
    shader = 0
  }
  return shader, vok && fok
}


