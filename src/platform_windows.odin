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
gMainThreadID : win32.DWORD = 0
gServiceWindow: win32.HWND
opengl32dll: win32.HMODULE

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
TARGET_MS_PER_FRAME :: 16

WIN32_SERVICE_CLASS_NAME :: "Win32ServiceClass"

WIN32_CREATE_WINDOW_MSG :: win32.WM_USER + 0x1337
WIN32_DELETE_WINDOW_MSG :: win32.WM_USER + 0x1338

Win32WindowStyle :: struct
{
  dwExStyle:win32.DWORD,
  lpClassName:win32.LPCWSTR,
  lpWindowName:win32.LPCWSTR,
  dwStyle:win32.DWORD,
  X:i32,
  Y:i32,
  nWidth:i32,
  nHeight:i32,
  hWndParent:win32.HWND,
  hMenu:win32.HMENU,
  hInstance:win32.HINSTANCE,
  lpParam:win32.LPVOID
}


main :: proc()
{
  serviceWindowClass: win32.WNDCLASSEXW = {
    cbSize = size_of(win32.WNDCLASSEXW),
    lpfnWndProc = win32_service_window_proc,
    hInstance = cast(win32.HINSTANCE)win32.GetModuleHandleW(nil),
    hIcon = win32.LoadIconA(nil, win32.IDI_APPLICATION),
    hCursor = win32.LoadCursorA(nil, win32.IDC_ARROW),
    hbrBackground = cast(win32.HBRUSH)win32.GetStockObject(win32.BLACK_BRUSH),
    lpszClassName = win32.utf8_to_wstring(WIN32_SERVICE_CLASS_NAME)
  }
  win32.RegisterClassExW(&serviceWindowClass)
  serviceWindow := win32.CreateWindowExW(
    0, serviceWindowClass.lpszClassName,
    win32.utf8_to_wstring("ServiceWindow"), 0,
    win32.CW_USEDEFAULT,
    win32.CW_USEDEFAULT,
    win32.CW_USEDEFAULT,
    win32.CW_USEDEFAULT,
    nil, nil, serviceWindowClass.hInstance, nil
  )
  gServiceWindow = serviceWindow

  win32.CreateThread(
    lpThreadAttributes = nil,
    dwStackSize = 0,
    lpStartAddress = win32_main_thread_entry,
    lpParameter = serviceWindow,
    dwCreationFlags = 0,
    lpThreadId = &gMainThreadID
  )

  for
  {
    message: win32.MSG
    win32.GetMessageW(&message, nil, 0, 0)
    win32.TranslateMessage(&message)
    switch message.message
    {
      case win32.WM_KEYDOWN, win32.WM_QUIT, win32.WM_SIZE,
        win32.WM_KEYUP, win32.WM_SYSKEYUP, win32.WM_SYSKEYDOWN:
      {
        win32.PostThreadMessageW(
          idThread = gMainThreadID,
          Msg = message.message,
          wParam = message.wParam,
          lParam = message.lParam
        )
      }
      case:
      {
        win32.DispatchMessageW(&message)
      }
    }
  }
}

win32_main_thread_entry :: proc "std" (param: rawptr) -> u32
{
  context = runtime.default_context()
  window, ok := win32_init_window("OpenGL", WINDOW_WIDTH, WINDOW_HEIGHT)
  if !ok
  {
    fmt.eprintln("could not create a win32 window")
    win32.ExitProcess(1)
  }
  dc := win32.GetDC(window)
  glCtx, loaded_opengl := win32_init_opengl(dc, 4, 3)
  if !loaded_opengl do win32.ExitProcess(1)
  free_all(context.temp_allocator)



  stateMemory, res := mem.alloc(app.STATE_UPPER_BOUND)
  assert(res == runtime.Allocator_Error.None)


  perfFrequency: win32.LARGE_INTEGER
  win32.QueryPerformanceFrequency(&perfFrequency)
  lastTime, endTime, lastWorkTime: win32.LARGE_INTEGER
  dt: f32
  win32.QueryPerformanceCounter(&lastTime)
  lastWorkTime = lastTime




  input: app.Input

  mainLoop: for gRunning
  {
    message: win32.MSG
    for win32.PeekMessageW(&message, nil, 0, 0, win32.PM_REMOVE)
    {
      switch message.message
      {
        case win32.WM_QUIT, win32.WM_CLOSE, win32.WM_DESTROY:
        {
          gRunning = false
        }
        case win32.WM_SIZE:
        {
          rect: win32.RECT
          win32.GetClientRect(window, &rect);
          gl.Viewport(
            rect.left,
            rect.top,
            rect.right - rect.left,
            rect.bottom - rect.top,
          );
        }
        case win32.WM_KEYDOWN, win32.WM_KEYUP, win32.WM_SYSKEYDOWN,
          win32.WM_SYSKEYUP:
        {
          vkCode  := message.wParam
          isDown  := ((message.lParam & (1 << 30)) == 0)
          wasDown := ((message.lParam & (1 << 29)) == 1)
          if vkCode == win32.VK_UP
          {
            input.up.isDown  = isDown
            input.up.wasDown = wasDown
          }
          if vkCode == win32.VK_DOWN
          {
            input.down.isDown  = isDown
            input.down.wasDown = wasDown
          }
        }
      }
      //paint: win32.PAINTSTRUCT
      //hdx := win32.BeginPaint(windowHandle, &paint)
      //if gInitedOpengl
      //{
      //  rect: win32.RECT
      //  win32.GetClientRect(windowHandle, &rect);
      //  gl.Viewport(
      //    rect.left,
      //    rect.top,
      //    rect.right - rect.left,
      //    rect.bottom - rect.top,
      //  );
      //}
      //win32.EndPaint(windowHandle, &paint)
    }
    app.update_and_render(stateMemory, input, dt)

    win32.SwapBuffers(dc)
    free_all(context.temp_allocator)


    win32.QueryPerformanceCounter(&endTime)
    rawTimeElapsed := endTime - lastTime;
    workTimeElapsed := endTime - lastWorkTime
    dt = cast(f32)rawTimeElapsed/cast(f32)perfFrequency


    msPerFrame := (cast(f32)workTimeElapsed/cast(f32)perfFrequency) * 1000.0
    if cast(win32.DWORD)msPerFrame < TARGET_MS_PER_FRAME
    {
      sleepTime := cast(win32.DWORD)(TARGET_MS_PER_FRAME - cast(win32.DWORD)msPerFrame)
      win32.Sleep(sleepTime)
    }
    win32.QueryPerformanceCounter(&lastWorkTime)
    lastTime = endTime


  }
  win32.ExitProcess(0)
  //os.exit(0)
}



win32_init_window :: proc(name: string, width, height: i32) -> (window: win32.HWND, ok: bool)
{
  instance := cast(win32.HINSTANCE)win32.GetModuleHandleW(nil)
  windowClass: win32.WNDCLASSW = {
    style = win32.CS_HREDRAW | win32.CS_VREDRAW,
    lpfnWndProc = win32_display_window_proc,
    hInstance = instance,
    lpszClassName = win32.utf8_to_wstring("OdinGlClass")
  }
  if !bool(win32.RegisterClassW(&windowClass))
  {
    fmt.eprintfln("Registering the class failed!")
    return nil, false
  }
  wndStyle: Win32WindowStyle = {
    dwExStyle = 0,
    lpClassName = windowClass.lpszClassName,
    lpWindowName = win32.utf8_to_wstring(name),
    dwStyle = win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
    X = win32.CW_USEDEFAULT, Y = win32.CW_USEDEFAULT,
    nWidth = width, nHeight = height,
    hWndParent = nil, hMenu = nil, hInstance = instance, lpParam = nil
  }
  resultWindow := cast(win32.HWND)cast(uintptr)win32.SendMessageW(gServiceWindow, WIN32_CREATE_WINDOW_MSG, cast(win32.WPARAM)&wndStyle, 0)
  if resultWindow == nil
  {
    fmt.println("Creating the window failed, its nil")
    return nil, false
  }
  return resultWindow, true
}

win32_display_window_proc :: proc "stdcall" (windowHandle: win32.HWND, message: u32, wParam: uintptr, lParam: int) -> win32.LRESULT
{
  result : win32.LRESULT
  switch message
  {
  case win32.WM_DESTROY, win32.WM_CLOSE, win32.WM_QUIT,
     win32.WM_SIZE, win32.WM_KEYDOWN, win32.WM_KEYUP,
      win32.WM_SYSKEYDOWN, win32.WM_SYSKEYUP:
    {
      win32.PostThreadMessageW(gMainThreadID, message, wParam, lParam)
    }

    case: 
    {
       result = win32.DefWindowProcW(windowHandle, message, wParam, lParam)
    }
  }
  return result
}


win32_service_window_proc :: proc "stdcall" (windowHandle: win32.HWND, message: u32, wParam: uintptr, lParam: int) -> win32.LRESULT
{
  result: win32.LRESULT
  switch message
  {
    case WIN32_CREATE_WINDOW_MSG:
    {
      wndStyle := cast(^Win32WindowStyle)wParam
      result = cast(win32.LRESULT)cast(uintptr)win32.CreateWindowExW(
        dwExStyle = wndStyle.dwExStyle,
        lpClassName = wndStyle.lpClassName,
        lpWindowName = wndStyle.lpWindowName,
        dwStyle = wndStyle.dwStyle,
        X = wndStyle.X,
        Y = wndStyle.Y,
        nWidth = wndStyle.nWidth,
        nHeight = wndStyle.nHeight,
        hWndParent = wndStyle.hWndParent,
        hMenu = wndStyle.hMenu,
        hInstance = wndStyle.hInstance,
        lpParam = wndStyle.lpParam
      )
    }
    case WIN32_DELETE_WINDOW_MSG:
    {
      win32.DestroyWindow(cast(win32.HWND)wParam)
    }
    case:
    {
      result = win32.DefWindowProcW(windowHandle, message, wParam, lParam)
    }
  }
  return result;
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

