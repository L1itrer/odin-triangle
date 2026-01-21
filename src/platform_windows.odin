package main

import win32 "core:sys/windows"
import gl "vendor:OpenGL"
import "core:fmt"
import "base:runtime"
import "core:c"
import "app"
import "core:mem"

gRunning: bool = true
gInitedOpengl := false
opengl32dll: win32.HMODULE

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
TARGET_MS_PER_FRAME :: 16

main :: proc()
{
  window, ok := win32_init_window("OpenGL", WINDOW_WIDTH, WINDOW_HEIGHT)
  if !ok
  {
    fmt.eprintln("could not create a win32 window")
    return
  }
  dc := win32.GetDC(window)
  glCtx, loaded_opengl := win32_init_opengl(dc, 4, 3)
  if !loaded_opengl do return
  free_all(context.temp_allocator)
  stateMemory, res := mem.alloc(app.STATE_UPPER_BOUND)
  assert(res == runtime.Allocator_Error.None)
  perfFrequency: win32.LARGE_INTEGER
  win32.QueryPerformanceFrequency(&perfFrequency)
  lastTime, endTime: win32.LARGE_INTEGER
  dt: f32
  win32.QueryPerformanceCounter(&lastTime)
  mainLoop: for gRunning
  {
    message: win32.MSG
    for win32.PeekMessageW(&message, nil, 0, 0, win32.PM_REMOVE)
    {
      if message.message == win32.WM_QUIT || message.message == win32.WM_CLOSE || message.message == win32.WM_DESTROY
      {
        gRunning = false
      }
      win32.TranslateMessage(&message)
      win32.DispatchMessageW(&message)
    }
    app.update_and_render(stateMemory, dt)

    win32.SwapBuffers(dc)
    free_all(context.temp_allocator)
    win32.QueryPerformanceCounter(&endTime)
    rawTimeElapsed := endTime - lastTime;
    dt = cast(f32)rawTimeElapsed/cast(f32)perfFrequency
    msPerFrame := dt * 1000.0
    if cast(win32.DWORD)msPerFrame < TARGET_MS_PER_FRAME
    {
      sleepTime := cast(win32.DWORD)(TARGET_MS_PER_FRAME - cast(win32.DWORD)msPerFrame)
      win32.Sleep(sleepTime)
    }
    win32.QueryPerformanceCounter(&lastTime)
  }
}



win32_init_window :: proc(name: string, width, height: i32) -> (window: win32.HWND, ok: bool)
{
  instance := cast(win32.HINSTANCE)win32.GetModuleHandleW(nil)
  windowClass: win32.WNDCLASSW = {
    style = win32.CS_HREDRAW | win32.CS_VREDRAW,
    lpfnWndProc = win32_window_proc,
    hInstance = instance,
    lpszClassName = win32.utf8_to_wstring("OdinGlClass")
  }
  if !bool(win32.RegisterClassW(&windowClass))
  {
    fmt.eprintfln("Registering the class failed!")
    return nil, false
  }
  result_window := win32.CreateWindowExW(
    dwExStyle = 0,
    lpClassName = windowClass.lpszClassName,
    lpWindowName = win32.utf8_to_wstring(name),
    dwStyle = win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
    X = win32.CW_USEDEFAULT, Y = win32.CW_USEDEFAULT,
    nWidth = width, nHeight = height,
    hWndParent = nil, hMenu = nil, hInstance = instance, lpParam = nil
  )
  if result_window == nil
  {
    return nil, false
  }
  return result_window, true
}

win32_window_proc :: proc "stdcall" (windowHandle: win32.HWND, message: u32, wParam: uintptr, lParam: int) -> win32.LRESULT
{
  result : win32.LRESULT
  switch message
  {
    case win32.WM_DESTROY, win32.WM_CLOSE, win32.WM_QUIT:
    {
      gRunning = false
    }
    case win32.WM_SIZE:
    {
      if gInitedOpengl
      {
        rect: win32.RECT
        win32.GetClientRect(windowHandle, &rect);
        gl.Viewport(
          rect.left,
          rect.top,
          rect.right - rect.left,
          rect.bottom - rect.top,
        );
      }
    }
    case win32.WM_PAINT:
    {
      paint: win32.PAINTSTRUCT
      hdx := win32.BeginPaint(windowHandle, &paint)
      win32.EndPaint(windowHandle, &paint)
    }

    case: 
    {
       result = win32.DefWindowProcW(windowHandle, message, wParam, lParam)
    }
  }
  return result
}

win32_init_opengl :: proc(realDc: win32.HDC, majorVersion, minorVersion: c.int) ->
(glContext: win32.HGLRC, ok: bool)
{
  desiredPixelFormat, suggestedPixelFormat: win32.PIXELFORMATDESCRIPTOR
  dummyWindowClass: win32.WNDCLASSW = {
    style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
    lpfnWndProc = win32.DefWindowProcW,
    hInstance = cast(win32.HINSTANCE)win32.GetModuleHandleW(nil),
    lpszClassName = win32.utf8_to_wstring("opengldummyclass")
  }
  assert(bool(win32.RegisterClassW(&dummyWindowClass)))
  dummyWindow := win32.CreateWindowExW(0, dummyWindowClass.lpszClassName, win32.utf8_to_wstring("dontcare"), 0, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, nil, nil, dummyWindowClass.hInstance, nil)
  assert(dummyWindow != nil)
  dc := win32.GetDC(dummyWindow)
  desiredPixelFormat = {
    nSize = size_of(win32.PIXELFORMATDESCRIPTOR),
    nVersion = 1,
    dwFlags = win32.PFD_SUPPORT_OPENGL | win32.PFD_DRAW_TO_WINDOW | win32.PFD_DOUBLEBUFFER,
    cColorBits = 32,
    cAlphaBits = 8,
    iLayerType = win32.PFD_MAIN_PLANE
  }
  suggestedFormatIndex := win32.ChoosePixelFormat(dc, &desiredPixelFormat)
  win32.DescribePixelFormat(dc, 
    suggestedFormatIndex, 
    size_of(win32.PIXELFORMATDESCRIPTOR), 
    &suggestedPixelFormat
  )
  if !bool(win32.SetPixelFormat(dc, suggestedFormatIndex, &suggestedPixelFormat))
  {
    fmt.eprintln("could not set win32 pixel format")
    return nil, false
  }
  dummyContext := win32.wglCreateContext(dc)
  result := win32.wglMakeCurrent(dc, dummyContext)
  assert(bool(result), "How the fuck does your computer not have opengl")
  xCreateContextAttribsARB : win32.CreateContextAttribsARBType = cast(win32.CreateContextAttribsARBType)win32.wglGetProcAddress("wglCreateContextAttribsARB")
  xChoosePixelFormatARB : win32.ChoosePixelFormatARBType = cast(win32.ChoosePixelFormatARBType)win32.wglGetProcAddress("wglChoosePixelFormatARB")
  assert(xCreateContextAttribsARB != nil && xChoosePixelFormatARB != nil, "Could not locate opengl startup procs")
  win32.wglMakeCurrent(dc, nil)
  win32.wglDeleteContext(dummyContext)
  win32.ReleaseDC(dummyWindow, dc)
  win32.DestroyWindow(dummyWindow)


  // ACTUAL INITIALIZATION HAPENS HERE

  pixelFormatAttribs := [?]i32 {
    win32.WGL_DRAW_TO_WINDOW_ARB, i32(gl.GL_Enum.TRUE),
    win32.WGL_SUPPORT_OPENGL_ARB, i32(gl.GL_Enum.TRUE),
    win32.WGL_DOUBLE_BUFFER_ARB, i32(gl.GL_Enum.TRUE),
    win32.WGL_ACCELERATION_ARB, win32.WGL_FULL_ACCELERATION_ARB,
    win32.WGL_PIXEL_TYPE_ARB, win32.WGL_TYPE_RGBA_ARB,
    win32.WGL_COLOR_BITS_ARB, 32,
    win32.WGL_DEPTH_BITS_ARB, 24,
    win32.WGL_STENCIL_BITS_ARB, 8,
    0
  }
  pixelFormat := [1]i32{}
  numFormats := [1]win32.DWORD{}
  xChoosePixelFormatARB(
    realDc, 
    raw_data(pixelFormatAttribs[:]), 
    nil, 
    1, 
    raw_data(pixelFormat[:]), 
    raw_data(numFormats[:])
  )
  assert(numFormats != 0, "xChoosePixelFomratARB failed")
  win32.DescribePixelFormat(realDc, pixelFormat[0], size_of(desiredPixelFormat), &desiredPixelFormat)
  result = win32.SetPixelFormat(realDc, pixelFormat[0], &desiredPixelFormat)
  assert(bool(result), "Could not set pixel format")

  contextFlags : i32 = 0
  when ODIN_DEBUG
  {
    contextFlags |= win32.WGL_CONTEXT_DEBUG_BIT_ARB
  }
  glAttribs := [?]c.int{
    win32.WGL_CONTEXT_MAJOR_VERSION_ARB, majorVersion,
    win32.WGL_CONTEXT_MINOR_VERSION_ARB, minorVersion,
    win32.WGL_CONTEXT_FLAGS_ARB, contextFlags,
    win32.WGL_CONTEXT_PROFILE_MASK_ARB, win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
    0
  }
  openglContext := xCreateContextAttribsARB(realDc, nil, raw_data(glAttribs[:]))
  assert(openglContext != nil, "could not create opengl context")
  result = win32.wglMakeCurrent(realDc, openglContext)
  assert(bool(result), "could not set opengl context to current")


  opengl_proc_address :: proc(address: rawptr, name: cstring)
  {
    // if it's a new (ver> 1.1) function you have to load it through wglGetProcAddress
    // if it's an old function you have to load it from opengl32.dll
    // the genius of microsoft developers cannot be understated
    write_address : ^rawptr = cast(^rawptr)address
    proc_address := win32.wglGetProcAddress(name)
    if proc_address == nil
    {
      proc_address = win32.GetProcAddress(opengl32dll, name)
    }
    assert(proc_address != nil)
    write_address^ = proc_address
  }
  opengl32dll = win32.LoadLibraryW(win32.utf8_to_wstring("opengl32.dll"))
  assert(opengl32dll != nil)
  gl.load_up_to(int(majorVersion), int(minorVersion), opengl_proc_address)
  gInitedOpengl = true

  return openglContext, true
}
