package main

import "core:fmt"

import "vendor:directx/dxgi"
import "vendor:directx/d3d11"
import "vendor:glfw"

main :: proc() {
    window, hwnd := createWindow()
    defer glfw.DestroyWindow(window)

    directXState := initDirectX(hwnd)

    for !glfw.WindowShouldClose(window) {
        render(&directXState)
        glfw.PollEvents()
    }
}