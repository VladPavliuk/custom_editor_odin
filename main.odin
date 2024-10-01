package main

import win32 "core:sys/windows"
import "core:text/edit"
import "core:time"
import "core:mem"
import "base:runtime"

main :: proc() {
    // for Debug only!
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    context.allocator = mem.tracking_allocator(&tracker)
    default_context = context

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

        // checkTabFilesExistance(windowData.fileTabs[:])
        // startTimer()
        checkTabFileExistance(getActiveTab())
        
        if windowData.sinceExplorerSync > windowData.explorerSyncInterval {
            validateExplorerItems(&windowData.explorer)
            windowData.sinceExplorerSync = 0.0
        }
        windowData.sinceExplorerSync += windowData.delta
        // stopTimer()

        inputState.wasLeftMouseButtonDown = false
        inputState.wasLeftMouseButtonUp = false
        inputState.deltaMousePosition = { 0, 0 }
        inputState.scrollDelta = 0

        windowData.delta = time.duration_seconds(time.tick_diff(beforeFrame, time.tick_now()))

        free_all(context.temp_allocator)
    }

    free_all(context.temp_allocator)
    removeWindowData()
    clearDirectX()

    for _, leak in tracker.allocation_map {
		fmt.printf("%v leaked %m\n", leak.location, leak.size)
	}
	for bad_free in tracker.bad_free_array {
		fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
	}
}