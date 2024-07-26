package main

import "vendor:glfw"
import win32 "core:sys/windows"

createWindow :: proc() -> (glfw.WindowHandle, win32.HWND) {
    assert(i32(glfw.Init()) != 0)

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    
    window := glfw.CreateWindow(800, 800, "test", nil, nil)

    glfw.MakeContextCurrent(window)
    
    hwnd := glfw.GetWin32Window(window)

    return window, hwnd
}