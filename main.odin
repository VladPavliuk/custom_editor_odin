package main

import "vendor:glfw"

main :: proc() {
    window, hwnd, windowData := createWindow()
    defer glfw.DestroyWindow(window)

    directXState := initDirectX(hwnd)
    defer clearDirectX(&directXState)

    glfw.SetKeyCallback(window, keyboardHandler)
    
    initGpuResources(&directXState)
    
    fontCharIndex := 0
    for !glfw.WindowShouldClose(window) {
        render(&directXState, windowData)

        fontCharIndex = (fontCharIndex + 1) % len(directXState.fontChars) 
        fontChar := directXState.fontChars[fontCharIndex]
        updateConstantBuffer(&fontChar, directXState.constantBuffers[.FONT_GLYPH_LOCATION], &directXState)

        glfw.PollEvents()
    }
}