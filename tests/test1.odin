package tests

import "core:testing"
import "core:sync"
import "core:thread"
import "core:log"
// import "core:debug"
import "core:fmt"

import win32 "core:sys/windows"

import main "../"

runApp :: proc(windowDataPtr: ^^main.WindowData, wasWindowCreated: ^bool) {
    windowData := main.preCreateWindow()

    windowDataPtr^ = windowData
    wasWindowCreated^ = true

    main.run(windowData)
}

@(test)
just_run_and_close :: proc(t: ^testing.T) {
    windowData: ^main.WindowData
    wasWindowCreated := false
    app := thread.create_and_start_with_poly_data2(&windowData, &wasWindowCreated, runApp, context)

    for !wasWindowCreated {}

    win32.SendMessageW(windowData.parentHwnd, win32.WM_DESTROY, 0, 0)

    for !thread.is_done(app) { }

    thread.join(app)
    thread.destroy(app)
}
