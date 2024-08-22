package main

import win32 "core:sys/windows"

import "core:text/edit"

main :: proc() {
    hwnd, windowData := createWindow({ 800, 800 })

    directXState := initDirectX(hwnd)
    windowData.directXState = &directXState
    defer clearDirectX(&directXState)
    
    initGpuResources(&directXState, windowData)
    
    msg: win32.MSG
    for msg.message != win32.WM_QUIT {
        if win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
            win32.TranslateMessage(&msg)
            win32.DispatchMessageW(&msg)
            continue
        }
        
        edit.update_time(&windowData.inputState)
        render(&directXState, windowData)

        windowData.wasLeftMouseButtonDown = false
        windowData.wasLeftMouseButtonUp = false
    }
}