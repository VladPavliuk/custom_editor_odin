package main

import win32 "core:sys/windows"
import "core:text/edit"
import "core:time"
import "core:fmt"

main :: proc() {
    createWindow({ 800, 800 })

    initDirectX()
    
    initGpuResources()

    msg: win32.MSG
    for msg.message != win32.WM_QUIT {
        beforeFrame := time.tick_now()
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

        windowData.delta = time.duration_seconds(time.tick_diff(beforeFrame, time.tick_now()))
    }

    removeWindowData()
    clearDirectX()
}