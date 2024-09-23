package tests

import "base:intrinsics"
import "core:testing"
import "core:strings"
import "core:os"
import "core:time"

import win32 "core:sys/windows"

import main "../"

// @(test)
// type_and_save :: proc(t: ^testing.T) {
//     appThread, windowData := startApp(proc(windowData: ^main.WindowData) -> bool {
//         return windowData.windowCreated
//     })
    
//     time.sleep(1_000_0000000)
//     defer stopApp(appThread, windowData.parentHwnd)
// }

@(test)
just_run_and_close :: proc(t: ^testing.T) {
    appThread, windowData := startApp(proc(windowData: ^main.WindowData) -> bool {
        return windowData.windowCreated
    })
    defer stopApp(appThread, windowData.parentHwnd)

    text := "all work and no play makes jack a dull boy yeah"

    typeStringOnKeyboard(windowData.parentHwnd, text)

    testing.expect_value(t, strings.to_string(main.windowData.editorCtx.text), text)
}

@(test)
type_and_save :: proc(t: ^testing.T) {
    appThread, windowData := startApp(proc(windowData: ^main.WindowData) -> bool {
        return windowData.windowCreated
    })
    defer stopApp(appThread, windowData.parentHwnd)

    text := "all work and no play makes jack a dull boy"

    typeStringOnKeyboard(windowData.parentHwnd, text)

    // time.sleep(1_00_000_000)
    windowRect: win32.RECT
    win32.GetWindowRect(windowData.parentHwnd, &windowRect)

    clickMouse({
        { windowRect.left + 30, windowRect.top + 50 },
        { windowRect.left + 30, windowRect.top + 90 },
    })

    time.sleep(2_000_000_000)

    typeStringOnKeyboard(windowData.parentHwnd, "test1.txt")
    clickEnter()
    time.sleep(1_000_000_000)

    testing.expect(t, os.is_file(windowData.openedFilePath), "file was not created")
    
    saveFileContent, err := os.read_entire_file_from_filename_or_err(windowData.openedFilePath)
    testing.expect(t, err == nil, "could not read saved file")
    defer delete(saveFileContent)

    testing.expect_value(t, string(saveFileContent), text)

    os.remove(windowData.openedFilePath)
}

