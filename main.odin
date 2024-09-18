package main

import win32 "core:sys/windows"
import "core:text/edit"

main :: proc() {
    createWindow({ 800, 800 })

    initDirectX()
    
    initGpuResources()

    msg: win32.MSG
    for msg.message != win32.WM_QUIT {
        if win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
            win32.TranslateMessage(&msg)
            win32.DispatchMessageW(&msg)
            continue
        }

        edit.update_time(&windowData.editableTextCtx.editorState)
        render()

        inputState.wasLeftMouseButtonDown = false
        inputState.wasLeftMouseButtonUp = false
        inputState.deltaMousePosition = { 0, 0 }
        inputState.scrollDelta = 0
    }

    removeWindowData()
    clearDirectX()
}