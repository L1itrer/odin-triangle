package main

import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:OpenGL"
import "vendor:glfw"

POSITION_INDEX :: 0

create_shader :: proc(vertexShader, fragmentShader : string) -> (u32, bool)
{
    program := OpenGL.CreateProgram()
    vs, ok := compile_shader(OpenGL.VERTEX_SHADER, vertexShader)
    if !ok do return vs, false
    fs, ok1 := compile_shader(OpenGL.FRAGMENT_SHADER, fragmentShader)
    if !ok1 do return fs, false

    OpenGL.AttachShader(program, vs)
    OpenGL.AttachShader(program, fs)
    OpenGL.LinkProgram(program)
    OpenGL.ValidateProgram(program)
    OpenGL.UseProgram(program) // i should be handling errors here

    OpenGL.DeleteShader(vs)
    OpenGL.DeleteShader(fs)

    return program, true
}

compile_shader :: proc(type : u32, sourceShader : string) -> (id: u32, ok: bool)
{
    sourceShader := sourceShader
    id = OpenGL.CreateShader(type)
    src := strings.clone_to_cstring(sourceShader)
    OpenGL.ShaderSource(id, 1, &src, nil)
    OpenGL.CompileShader(id)

    result : i32 = ---
    OpenGL.GetShaderiv(id, OpenGL.COMPILE_STATUS, &result)
    ok = false if result == 0 else true

    return id, ok
}



main :: proc() {
    if !glfw.Init()
    {
        os.exit(-1)
    }
    defer glfw.Terminate()

    window := glfw.CreateWindow(640, 480, "Hello World", nil, nil)

    if window == nil
    {
        glfw.Terminate()
        os.exit(-1)
    }

    glfw.MakeContextCurrent(window)
    //OpenGL is not a library we actually need to manually load all OpenGL function adresses into a bunch of funcion
    //pointers, in C we would use a library like glew to automate that process, here I use a function from odin
    OpenGL.load_up_to(4, 6, glfw.gl_set_proc_address)

    version := OpenGL.GetString(OpenGL.VERSION)
    fmt.printfln("OpenGL version: %v", version)

    positions := [?]f32{
        -0.5, -0.5,
         0.5, -0.5,
         0.5,  0.5,
        -0.5,  0.5
    }

    indecies := [?]u32 {
        0,1,2,
        2,3,0
    }

    buffer : u32 = ---
    vao : u32 = ---
    index_buffer_object : u32 = ---
    OpenGL.GenVertexArrays(1, &vao)
    OpenGL.BindVertexArray(vao)
    OpenGL.GenBuffers(1, &buffer) //GenBuffers(u32: amount of buffers, ^u32 buffer id)
    OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, buffer) //what's bound is what we operate on
    //we need to tell opengl how the data is laid out in memory and provide it with data
    //in this case we supply an array buffer which has a size of 6 floats, it's address and a hint as to how it's used
    OpenGL.BufferData(OpenGL.ARRAY_BUFFER, size_of(positions), &positions, OpenGL.STATIC_DRAW)
    OpenGL.EnableVertexAttribArray(POSITION_INDEX)
    //attributes of well, an attribute, a position has an index, is made up of 2 floats, it's already normalized (false)
    //the sizeof the entire vertex is size of 2 floats and the attribute starts at "address" 0 in a vertex
    OpenGL.VertexAttribPointer(POSITION_INDEX,2,OpenGL.FLOAT, false, size_of(f32)* 2, 0)

    OpenGL.GenBuffers(1, &index_buffer_object)
    OpenGL.BindBuffer(OpenGL.ELEMENT_ARRAY_BUFFER, index_buffer_object)
    OpenGL.BufferData(OpenGL.ELEMENT_ARRAY_BUFFER, size_of(indecies), &indecies, OpenGL.STATIC_DRAW)

    //loading the compiled shader, odin has a ready function for that but let's pretend that it doesn't
    shader, ok := create_shader(
        string(#load("resources/shaders/vertex.glsl")),
        string(#load("resources/shaders/fragment.glsl")));
    if !ok
    {
        length : i32 = ---
        OpenGL.GetShaderiv(shader, OpenGL.INFO_LOG_LENGTH, &length)
        buffer := make_slice([]u8 , length) //TODO: allocate on stack not heap
        OpenGL.GetShaderInfoLog(shader, length, &length, raw_data(buffer))
        fmt.printfln("[ERROR] Failed to compile shader:\n %v", string(buffer))
        OpenGL.DeleteShader(shader)
        delete(buffer)
        os.exit(-1)
    }
    //shader needs to be deleted to avoid gpu memory leaks
    defer OpenGL.DeleteProgram(shader)

    for !glfw.WindowShouldClose(window)
    {
        OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)

        OpenGL.DrawElements(OpenGL.TRIANGLES, 6, OpenGL.UNSIGNED_INT, nil)


        glfw.SwapBuffers(window)

        glfw.PollEvents()
    }


}
