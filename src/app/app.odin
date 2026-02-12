package app

import gl "vendor:OpenGL"
import "core:fmt"
import "base:runtime"
import "core:math"
import stbi "vendor:stb/image"
import "core:c"

Shader :: u32

State :: struct{
  initialized: b32,
  vao: [1]u32,
  vbo: [1]u32,
  ebo: [1]u32,
  textures : [2]Texture,
  shaders: [3]u32,
  runningTimeSeconds: f32,
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

  // positions          colors
@rodata
alterVerticies := [?] f32 {
//         0.5 , -0.5 , 0.0 ,  1.0 , 0.0 , 0.0 ,  // bottom right
//        -0.5 , -0.5 , 0.0 ,  0.0 , 1.0 , 0.0 ,  // bottom le t
//         0.0 ,  0.5 , 0.0 ,  0.0 , 0.0 , 1.0    // top 
  -0.75, YBOT, 0.0,     0.0, 1.0, 0.0, // bottom middle
  -0.5, YTOP, 0.0,     0.0, 0.0, 1.0, // right top
  -1.0, YTOP, 0.0,     1.0, 0.0, 0.0, // top left
}

@rodata
indecies0 := [?]u32 {
  0, 1, 2,
}

@rodata
indecies1 := [?]u32 {
  2, 3, 4
}


// positions, colors, tex coords
@rodata
texturedVerticies := [?] f32 {
     0.5,  0.5, 0.0,   1.0, 0.0, 0.0,   1.0, 1.0,   // top right
     0.5, -0.5, 0.0,   0.0, 1.0, 0.0,   1.0, 0.0,   // bottom right
    -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0,   // bottom let
    -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,   0.0, 1.0    // top let
}

@rodata
texturedIndecies := [?]u32 {
  0, 1, 3,
  1, 2, 3
}

gl_debug_output :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr)
{
  context = runtime.default_context()
  fmt.printfln("---GL DEBUG MSG ------", id)
  fmt.printfln("  Message = %v, (code %v)", message, id)
  switch source
  {
    case cast(u32)gl.GL_Enum.DEBUG_SOURCE_API: fmt.println("  Source = API")
    case cast(u32)gl.GL_Enum.DEBUG_SOURCE_WINDOW_SYSTEM: fmt.println("  Source = WINDOW_SYSTEM")
    case cast(u32)gl.GL_Enum.DEBUG_SOURCE_SHADER_COMPILER: fmt.println("  Source = SHADER_COMPILER")
    case cast(u32)gl.GL_Enum.DEBUG_SOURCE_THIRD_PARTY: fmt.println("  Source = THIRD_PARTY")
    case cast(u32)gl.GL_Enum.DEBUG_SOURCE_OTHER: fmt.println("  Source = OTHER")
    case:
    {
      fmt.printfln("  Source = (unknown) %v", source)
    }
  }
  switch type
  {
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_ERROR:               fmt.println("  Type = Error")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_DEPRECATED_BEHAVIOR: fmt.println("  Type = Deprecated Behaviour")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_UNDEFINED_BEHAVIOR:  fmt.println("  Type = Undefined Behaviour")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_PORTABILITY:         fmt.println("  Type = Portability")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_PERFORMANCE:         fmt.println("  Type = Performance")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_MARKER:              fmt.println("  Type = Marker")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_PUSH_GROUP:          fmt.println("  Type = Push Group")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_POP_GROUP:           fmt.println("  Type = Pop Group")
    case cast(u32)gl.GL_Enum.DEBUG_TYPE_OTHER:               fmt.println("  Type = Other")
  }
  switch severity
  {     
    case cast(u32)gl.GL_Enum.DEBUG_SEVERITY_HIGH:         fmt.println("  Severity = high")
    case cast(u32)gl.GL_Enum.DEBUG_SEVERITY_MEDIUM:       fmt.println("  Severity = medium")
    case cast(u32)gl.GL_Enum.DEBUG_SEVERITY_LOW:          fmt.println("  Severity = low")
    case cast(u32)gl.GL_Enum.DEBUG_SEVERITY_NOTIFICATION: fmt.println("  Severity = notification")
  }
  fmt.printfln("---GL DEBUG END ------", id)
  if severity != cast(u32)gl.GL_Enum.DEBUG_SEVERITY_LOW || severity != cast(u32)gl.GL_Enum.DEBUG_SEVERITY_NOTIFICATION
  {
    fmt.println("serous bug")
  }
}


update_and_render :: proc(statePtr: rawptr, dt: f32)
{
  state : ^State = cast(^State)statePtr
  if !state.initialized
  {
    init(state)
  }
  state.runningTimeSeconds += dt
  render(state)
}

render :: proc(state: ^State)
{
  gl.ClearColor(0.1, 0.1, 0.1, 1.0)
  gl.Clear(u32(gl.GL_Enum.COLOR_BUFFER_BIT) | u32(gl.GL_Enum.DEPTH_BUFFER_BIT))

  gl.ActiveTexture(cast(u32)gl.GL_Enum.TEXTURE0)
  gl.BindTexture(cast(u32)gl.GL_Enum.TEXTURE_2D, cast(u32)state.textures[0])
  gl.ActiveTexture(cast(u32)gl.GL_Enum.TEXTURE1)
  gl.BindTexture(cast(u32)gl.GL_Enum.TEXTURE_2D, cast(u32)state.textures[1])

  dtColor := (math.sin_f32(state.runningTimeSeconds) + 1.0) / 2.0
  gl.UseProgram(state.shaders[2])
  shader_set(state.shaders[2], "dtColor", dtColor, dtColor, dtColor, 1.0)
  gl.Uniform2f(
      gl.GetUniformLocation(
        state.shaders[2],
        cast(cstring)"offset"
      ),
      0.0,
      0.0
  )
  shader_set(state.shaders[2], "texture1", 0)
  shader_set(state.shaders[2], "texture2", 1)
  gl.BindVertexArray(state.vao[0])
  gl.DrawElements(cast(u32)gl.GL_Enum.TRIANGLES, 6, cast(u32)gl.GL_Enum.UNSIGNED_INT, nil)
}

woodenContainerBytes := #load("../resources/images/container.jpg")
awesomefaceBytes := #load("../resources/images/awesomeface.png")

init :: proc(state: ^State)
{
  state.initialized = true
  flags: i32
  gl.GetIntegerv(cast(u32)gl.GL_Enum.CONTEXT_FLAGS, &flags)
  if bool(flags & cast(i32)gl.GL_Enum.CONTEXT_FLAG_DEBUG_BIT)
  {
    gl.Enable(cast(u32)gl.GL_Enum.DEBUG_OUTPUT)
    gl.Enable(cast(u32)gl.GL_Enum.DEBUG_OUTPUT_SYNCHRONOUS)
    gl.DebugMessageCallback(gl_debug_output, nil)
    gl.DebugMessageControl(
      source   = u32(gl.GL_Enum.DONT_CARE),
      type     = u32(gl.GL_Enum.DONT_CARE),
      severity = u32(gl.GL_Enum.DONT_CARE), 
      count    = 0,
      ids      = nil,
      enabled  = true
    )
  }
  // shader compilation
  vertexShaderSource := #load("../resources/shaders/vertex.glsl", cstring)
  fragmentShaderSource := #load("../resources/shaders/fragment.glsl", cstring)
  fragalterShaderSource := #load("../resources/shaders/fragalter.glsl", cstring)

  vertexRainbowSource := #load("../resources/shaders/rainbow_vert.glsl", cstring)
  fragmentRainbowSource := #load("../resources/shaders/rainbow_frag.glsl", cstring)
  shaderProgram, ok := shader_create(vertexShaderSource, fragmentShaderSource)
  assert(ok)
  alterShaderProgram, aok := shader_create(vertexShaderSource, fragalterShaderSource)
  assert(aok)
  rainbowShaderProgram, rok := shader_create(vertexRainbowSource, fragmentRainbowSource)
  assert(rok)



  // enable the shader
  gl.UseProgram(rainbowShaderProgram)
  state.shaders[0] = shaderProgram
  state.shaders[1] = alterShaderProgram
  state.shaders[2] = rainbowShaderProgram




  // vertex array creation
  vao: [1]u32
  gl.GenVertexArrays(len(vao), raw_data(vao[:]))
  // buffer creation
  vbo: [1]u32
  gl.GenBuffers(len(vbo), raw_data(vbo[:]))

  ebo: [1]u32
  gl.GenBuffers(len(ebo), raw_data(ebo[:]))
  // copy array into gpu memory

  gl.BindVertexArray(vao[0])
  gl.BindBuffer(cast(u32)gl.GL_Enum.ARRAY_BUFFER, vbo[0])
  gl.BufferData(
      cast(u32)gl.GL_Enum.ARRAY_BUFFER,
      size_of(texturedVerticies),
      &texturedVerticies,
      cast(u32)gl.GL_Enum.STATIC_DRAW
  )
  gl.BindBuffer(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, ebo[0])
  gl.BufferData(cast(u32)gl.GL_Enum.ELEMENT_ARRAY_BUFFER, size_of(texturedIndecies), &texturedIndecies, cast(u32)gl.GL_Enum.STATIC_DRAW)
  gl.VertexAttribPointer(0, 3, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(1, 3, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 8 * size_of(f32), 3*size_of(f32))
    gl.EnableVertexAttribArray(1)
  gl.VertexAttribPointer(2, 2, cast(u32)gl.GL_Enum.FLOAT, gl.FALSE, 8 * size_of(f32), 6*size_of(f32))
  gl.EnableVertexAttribArray(2)
  

  state.ebo = ebo
  state.vbo = vbo
  state.vao = vao



  state.textures[0] = texture_load(woodenContainerBytes[:])
  state.textures[1] = texture_load(awesomefaceBytes[:], true)




  // usefull for debugging, shows just frames of the triangles
  // gl.PolygonMode(cast(u32)gl.GL_Enum.FRONT_AND_BACK, auto_cast gl.GL_Enum.LINE)
}

Texture :: distinct u32

texture_load :: proc(imageBytes: []u8, flipImage: bool = false) -> Texture
{
  texture: u32 = ---
  w, h, nChannels: c.int = ---, ---, ---
  stbi.set_flip_vertically_on_load(cast(c.int)flipImage)
  loadedImageBytes := stbi.load_from_memory(
      raw_data(imageBytes[:]),
      cast(c.int)len(imageBytes[:]),
      &w, &h, &nChannels, 0
  )
  stbi.set_flip_vertically_on_load(0)
  defer stbi.image_free(loadedImageBytes)
  gl.GenTextures(1, &texture)
  gl.BindTexture(cast(u32)gl.GL_Enum.TEXTURE_2D, texture)
  internalFormat : i32 = nChannels == 3 ? cast(i32)gl.GL_Enum.RGB : cast(i32)gl.GL_Enum.RGBA
  gl.TexImage2D(
    target = cast(u32)gl.GL_Enum.TEXTURE_2D,
    level = 0,
    internalformat = internalFormat,
    width = w,
    height = h,
    border = 0, // lgeacy stuff
    format = cast(u32)internalFormat,
    type = cast(u32)gl.GL_Enum.UNSIGNED_BYTE,
    pixels = loadedImageBytes
  )
  gl.GenerateMipmap(cast(u32)gl.GL_Enum.TEXTURE_2D)


  gl.TexParameteri(
      cast(u32)gl.GL_Enum.TEXTURE_2D,
      cast(u32)gl.GL_Enum.TEXTURE_WRAP_S,
      cast(i32)gl.GL_Enum.REPEAT
  )
  gl.TexParameteri(
      cast(u32)gl.GL_Enum.TEXTURE_2D,
      cast(u32)gl.GL_Enum.TEXTURE_WRAP_T,
      cast(i32)gl.GL_Enum.REPEAT
  )
  gl.TexParameteri(
      cast(u32)gl.GL_Enum.TEXTURE_2D,
      cast(u32)gl.GL_Enum.TEXTURE_MIN_FILTER,
      cast(i32)gl.GL_Enum.LINEAR_MIPMAP_LINEAR
  )
  gl.TexParameteri(
      cast(u32)gl.GL_Enum.TEXTURE_2D,
      cast(u32)gl.GL_Enum.TEXTURE_MIN_FILTER,
      cast(i32)gl.GL_Enum.LINEAR
  )
  return cast(Texture)texture
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
  ok = vok && fok
  if ok
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
  return shader, ok
}

shader_set :: proc{
  shader_set_i32,
  shader_set_f32,
  shader_set_v4f,
}

shader_set_i32 :: proc(shader: Shader, name: cstring, val: i32)
{
  gl.Uniform1i(gl.GetUniformLocation(shader, name), val)
}

shader_set_f32 :: proc(shader: Shader, name: cstring, val: f32)
{
  gl.Uniform1f(gl.GetUniformLocation(shader, name), val)
}

shader_set_v4f :: proc(shader: Shader, name: cstring, x, y, z, w: f32)
{
  gl.Uniform4f(gl.GetUniformLocation(shader, name), x, y, z, w)
}
shader_set_v2f :: proc(shader: Shader, name: cstring, x, y: f32)
{
  gl.Uniform2f(gl.GetUniformLocation(shader, name), x, y)
}
