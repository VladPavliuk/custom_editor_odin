package main

import "vendor:glfw"

windowMaximizeProc :: proc "c" (window: glfw.WindowHandle, iconified: i32) {
    test := iconified
    // /assert(true)
} 

main :: proc() {
    window, hwnd, windowData := createWindow()
    defer glfw.DestroyWindow(window)

    directXState := initDirectX(hwnd)
    defer clearDirectX(&directXState)

    glfw.SetWindowMaximizeCallback(window, windowMaximizeProc)
    // glfw.Window(window, windowMaximizeProc)
    glfw.SetKeyCallback(window, keyboardHandler)
    
    initGpuResources(&directXState)
    
    // fontCharIndex := 0
    angle: f32 = 0.0
    beforeFrameTime := f32(glfw.GetTime())
    afterFrameTime := beforeFrameTime
    delta := afterFrameTime - beforeFrameTime

    for !glfw.WindowShouldClose(window) {
        beforeFrameTime = f32(glfw.GetTime())

        render(&directXState, windowData)

        // testing
        // fontCharIndex = (fontCharIndex + 1) % len(directXState.fontChars) 
        // fontChar := directXState.fontChars['A']

        // updateConstantBuffer(&fontChar, directXState.constantBuffers[.FONT_GLYPH_LOCATION], &directXState)

        // // angle += 1.1 * delta
        // modelMatrix := getScaleMatrix(3, 3, 1) * getTranslationMatrix(cursorPosition.x, cursorPosition.y, 0) * getRotationMatrix(angle, 0, 0)
        // updateConstantBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION], &directXState)
        //<

        glfw.PollEvents()

        afterFrameTime = f32(glfw.GetTime())
        delta = afterFrameTime - beforeFrameTime
    }
}