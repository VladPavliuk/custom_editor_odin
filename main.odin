package main

import "core:text/edit"
import "core:time"
import "core:mem"
import win32 "core:sys/windows"

main :: proc() {
    when ODIN_DEBUG {
        tracker: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracker, context.allocator)
        defer mem.tracking_allocator_destroy(&tracker)
        context.allocator = mem.tracking_allocator(&tracker)
        default_context = context
    }
    createWindow({ 800, 800 })

    initDirectX()
    
    initGpuResources()

    msg: win32.MSG
    for msg.message != win32.WM_QUIT {
        defer free_all(context.temp_allocator)

        beforeFrame := time.tick_now()
        if win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
            win32.TranslateMessage(&msg)
            win32.DispatchMessageW(&msg)
            continue
        }

        // NOTE: For some reasons if mouse double click happened, windows sends WM_LBUTTONDOWN and WM_LBUTTONUP at the same time??!
        // so we remove WM_LBUTTONUP and add DOUBLE_CLICK event
        if .LEFT_WAS_DOWN in inputState.mouse && .LEFT_WAS_UP in inputState.mouse {
            inputState.mouse -= {.LEFT_WAS_UP}
            inputState.mouse += {.LEFT_WAS_DOUBLE_CLICKED}
        }

        edit.update_time(&windowData.editableTextCtx.editorState)

        windowData.uiContext.deltaMousePosition = inputState.deltaMousePosition
        windowData.uiContext.mousePosition = inputState.mousePosition
        windowData.uiContext.scrollDelta = inputState.scrollDelta
        windowData.uiContext.mouse = inputState.mouse
        windowData.uiContext.wasPressedKeys = inputState.wasPressedKeys

        render()

        checkTabFileExistance(getActiveTab())

        if windowData.sinceExplorerSync > windowData.explorerSyncInterval {
            validateExplorerItems(&windowData.explorer)
            windowData.sinceExplorerSync = 0.0
        }
        windowData.sinceExplorerSync += windowData.delta

        inputState.mouse -= {.LEFT_WAS_DOWN, .LEFT_WAS_UP, .LEFT_WAS_DOUBLE_CLICKED, .RIGHT_WAS_DOWN, .RIGHT_WAS_UP}
        inputState.wasPressedKeys = {}

        inputState.deltaMousePosition = { 0, 0 }
        inputState.scrollDelta = 0

        windowData.delta = time.duration_seconds(time.tick_diff(beforeFrame, time.tick_now()))
        
        // when ODIN_DEBUG {    
        //     // fmt.println("Total allocated", tracker.current_memory_allocated)
        //     // fmt.println("Total freed", tracker.total_memory_freed)
        //     // fmt.println("Total leaked", tracker.total_memory_allocated - tracker.total_memory_freed)
        // }
    }

    removeWindowData()
    clearDirectX()
   
    when ODIN_DEBUG {
        for _, leak in tracker.allocation_map {
            fmt.printf("%v leaked %m\n", leak.location, leak.size)
        }
        for bad_free in tracker.bad_free_array {
            fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
        }

        fmt.println("Total allocated", tracker.total_memory_allocated)
        fmt.println("Total freed", tracker.total_memory_freed)
        fmt.println("Total leaked", tracker.total_memory_allocated - tracker.total_memory_freed)
    }
}