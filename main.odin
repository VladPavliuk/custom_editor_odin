package main

import "vendor:glfw"

main :: proc() {
    window, hwnd, windowData := createWindow()
    defer glfw.DestroyWindow(window)

    directXState := initDirectX(hwnd)
    defer clearDirectX(&directXState)

    glfw.SetKeyCallback(window, keyboardHandler)
    
    initGpuResources(&directXState)
    
    for !glfw.WindowShouldClose(window) {
        render(&directXState, windowData)

        glfw.PollEvents()
    }
}