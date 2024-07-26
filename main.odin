package main

import "vendor:glfw"

main :: proc() {
    window, hwnd := createWindow()
    defer glfw.DestroyWindow(window)

    directXState := initDirectX(hwnd)
    defer clearDirectX(&directXState)

    for !glfw.WindowShouldClose(window) {
        render(&directXState)
        glfw.PollEvents()
    }
}