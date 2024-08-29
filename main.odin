package main

import win32 "core:sys/windows"
import "core:text/edit"

main :: proc() {
    windowData := createWindow({ 800, 800 })

    directXState := initDirectX(windowData.parentHwnd)
    windowData.directXState = directXState
    
    initGpuResources(directXState, windowData)

    windowData.windowCreated = true

    msg: win32.MSG
    for msg.message != win32.WM_QUIT {
        if win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
            win32.TranslateMessage(&msg)
            win32.DispatchMessageW(&msg)
            continue
        }
        
        edit.update_time(&windowData.inputState)
        render(windowData.directXState, windowData)

        windowData.wasLeftMouseButtonDown = false
        windowData.wasLeftMouseButtonUp = false
    }

    removeWindowData(windowData)
    clearDirectX(windowData.directXState)
}