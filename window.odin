package main

import "base:runtime"
import "core:strings"

import "vendor:glfw"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

import win32 "core:sys/windows"

WindowData :: struct {
    isInputMode: bool,
    testInputString: strings.Builder,
}

createWindow :: proc() -> (glfw.WindowHandle, win32.HWND, ^WindowData) {
    assert(i32(glfw.Init()) != 0)

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    
    // window := glfw.CreateWindow(1920, 1080, "test", glfw.GetPrimaryMonitor(), nil)
    window := glfw.CreateWindow(800, 800, "test", nil, nil)

    glfw.MakeContextCurrent(window)
    
    hwnd := glfw.GetWin32Window(window)

    windowData := new(WindowData)
    windowData.testInputString = strings.builder_make()
    windowData.isInputMode = true

    glfw.SetWindowUserPointer(window, windowData)

    return window, hwnd, windowData
}

isKeyDown :: proc "c" (keyToCheck: i32, key: i32, action: i32) -> bool {
    return action == glfw.PRESS && keyToCheck == key
}

isKeyRepeated :: proc(keyToCheck: i32, key: i32, action: i32) -> bool {
    return action == glfw.REPEAT && keyToCheck == key
}

isKeyReleased :: proc(keyToCheck: i32, key: i32, action: i32) -> bool {
    return action == glfw.RELEASE && keyToCheck == key
}

keyboardHandler :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))
    
    if windowData.isInputMode {
        if isKeyDown(glfw.KEY_ENTER, key, action) || isKeyRepeated(glfw.KEY_ENTER, key, action) {
            strings.write_rune(&windowData.testInputString, '\n')
        }
    }

    if isKeyReleased(glfw.KEY_ESCAPE, key, action) {
        glfw.SetWindowShouldClose(window, true)
    }

    if isKeyDown(glfw.KEY_A, key, action) {
        //windowData.a += 0.1
    }

    if isKeyReleased(glfw.KEY_A, key, action) {
        // windowData.a -= .1
    }
}

keychardCharInputHandler :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    if windowData.isInputMode {
        strings.write_rune(&windowData.testInputString, codepoint)
    }
}