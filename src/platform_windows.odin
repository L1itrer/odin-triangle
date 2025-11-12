package main

import win32 "core:sys/windows"
main :: proc()
{
}
win32_init_window :: proc(width, height: i32) -> (window: win32.HWND, ok: bool)
{
  instance := cast(win32.HINSTANCE)win32.GetModuleHandleW(nil)
  windowClass: win32.WNDCLASSW = {
    style = win32.CS_HREDRAW | win32.CS_VREDRAW,
    lpfnWndProc = win32_window_proc,
    hInstance = instance,
    lpszClassName = win32.utf8_to_wstring("VulkanTriangleClass")
  }
  if !bool(win32.RegisterClassW(&windowClass))
  {
    fmt.eprintfln("Registering the class failed!")
    return nil, false
  }
  result_window := win32.CreateWindowExW(
    dwExStyle = 0,
    lpClassName = windowClass.lpszClassName,
    lpWindowName = win32.utf8_to_wstring("Vulkan triangle"),
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

    case: 
    {
       result = win32.DefWindowProcW(windowHandle, message, wParam, lParam)
    }
  }
  return result
}
