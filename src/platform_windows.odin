package main

import win32 "core:sys/windows"
import gl "vendor:OpenGL"
import "core:fmt"

gRunning: bool = true

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

main :: proc()
{
  window, ok := win32_init_window("OpenGL", WINDOW_WIDTH, WINDOW_HEIGHT)
  if !ok
  {
    fmt.eprintln("could not create a win32 window")
    return
  }
  ok = win32_init_opengl(window)
  if !ok do return
  for gRunning
  {
    message: win32.MSG
    for win32.PeekMessageW(&message, nil, 0, 0, win32.PM_REMOVE)
    {
      if message.message == win32.WM_QUIT do gRunning = false
      win32.TranslateMessage(&message)
      win32.DispatchMessageW(&message)
    }
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
    dwStyle = win32.WS_OVERLAPPED | win32.WS_VISIBLE | win32.WS_SYSMENU |
      win32.WS_MINIMIZEBOX | win32.WS_MINIMIZEBOX | win32.WS_CAPTION,
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
    case win32.WM_DESTROY, win32.WM_CLOSE:
    {
      gRunning = false
    }
    case win32.WM_SIZE:
    {
    }
    case win32.WM_ACTIVATEAPP:
    {
    }
    case win32.WM_PAINT:
    {
      dc := win32.GetDC(windowHandle)
      defer win32.ReleaseDC(windowHandle, dc)
      gl.ClearColor(1.0, 0.5, 0.5, 0.0)
      gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
      gl.Clear(u32(gl.GL_Enum.COLOR_BUFFER_BIT))
      win32.SwapBuffers(dc)
    }

    case: 
    {
       result = win32.DefWindowProcW(windowHandle, message, wParam, lParam)
    }
  }
  return result
}

win32_init_opengl :: proc(window: win32.HWND) -> (ok: bool)
{
  desiredPixelFormat, suggestedPixelFormat: win32.PIXELFORMATDESCRIPTOR
  dc := win32.GetDC(window)
 // dummyWindowClass: win32.WNDCLASSW = {
 //   style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
 //   lpfnWndProc = win32.DefWindowProcW,
 //   hInstance = cast(win32.HINSTANCE)win32.GetModuleHandleW(nil),
 //   lpszClassName = win32.utf8_to_wstring("opengldummyclass")
 // }
 // assert(bool(win32.RegisterClassW(&dummyWindowClass)))
 // window := win32.CreateWindowExW(0, dummyWindowClass.lpszClassName, win32.utf8_to_wstring("dontcare"), 0, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, nil, nil, dummyWindowClass.hInstance, nil)
 // assert(window != nil)
  //dc := win32.GetDC(window)
  //desiredPixelFormat = {
  //  nSize = size_of(win32.PIXELFORMATDESCRIPTOR),
  //  nVersion = 1,
  //  dwFlags = win32.PFD_SUPPORT_OPENGL | win32.PFD_DRAW_TO_WINDOW | win32.PFD_DOUBLEBUFFER,
  //  cColorBits = 32,
  //  cAlphaBits = 8,
  //  iLayerType = win32.PFD_MAIN_PLANE
  //}
  suggestedFormatIndex := win32.ChoosePixelFormat(dc, &desiredPixelFormat)
  win32.DescribePixelFormat(dc, 
    suggestedFormatIndex, 
    size_of(win32.PIXELFORMATDESCRIPTOR), 
    &suggestedPixelFormat
  )
  if !bool(win32.SetPixelFormat(dc, suggestedFormatIndex, &suggestedPixelFormat))
  {
    fmt.eprintln("could not set win32 pixel format")
    return false
  }
  dummyContext := win32.wglCreateContext(dc)
  result := win32.wglMakeCurrent(dc, dummyContext)
  assert(bool(result), "How the fuck does your computer not have opengl")
  xCreateContextAttribsARB : win32.CreateContextAttribsARBType = cast(win32.CreateContextAttribsARBType)win32.wglGetProcAddress("wglCreateContextAttribsARB")
  xChoosePixelFormatARBType : win32.ChoosePixelFormatARBType = cast(win32.ChoosePixelFormatARBType)win32.wglGetProcAddress("wglChoosePixelFormatARB")
  assert(xCreateContextAttribsARB != nil && xChoosePixelFormatARBType != nil, "Could not locate opengl startup procs")
  local_set_proc_address :: proc(p: rawptr, name: cstring)
  {
    procedure : ^rawptr = cast(^rawptr)p
    procedure^ = win32.wglGetProcAddress(name)
  }
  gl.load_3_3(local_set_proc_address)
  // win32.wglMakeCurrent(dc, nil)
  // win32.wglDeleteContext(dummyContext)
  win32.ReleaseDC(window, dc)


  // ACTUAL INITIALIZATION HAPENS HERE

  // pixelFormatAttribs: [?]win32.DWORD = {win32.WGL_DRAW_TO_WINDOW_ARB  }


  return true
}
