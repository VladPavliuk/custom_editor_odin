package tests

import "base:intrinsics"
import "core:testing"
import "core:strings"
import "core:os"
import "core:time"
import "core:sync"

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
    os.remove(main.editorStateFilePath)

    appThread, windowData := startApp(proc(windowData: ^main.WindowData) -> bool {
        return windowData.windowCreated
    })
    defer stopApp(appThread, windowData.parentHwnd)

    text := "all work and no play makes jack a dull boy yeah"

    typeStringOnKeyboard(windowData.parentHwnd, text)

    testing.expect_value(t, strings.to_string(main.getActiveTabContext().text), text)
}

@(test)
basic_file_search :: proc(t: ^testing.T) {
    os.remove(main.editorStateFilePath)

    appThread, windowData := startApp(proc(windowData: ^main.WindowData) -> bool {
        return windowData.windowCreated
    })
    defer stopApp(appThread, windowData.parentHwnd)

    time.sleep(200_000_000)

    text := "all work and no play makes jack a dull boy. work"

    typeStringOnKeyboard(windowData.parentHwnd, text)

    clickCtrlF()

    time.sleep(100_000_000)
    testing.expect(t, sync.atomic_load(&windowData.isFileSearchOpen))

    typeStringOnKeyboard(windowData.parentHwnd, "work")

    clickEnter()
    testing.expect_value(t, 1, int(sync.atomic_load(&windowData.currentFileSearchTermIndex)))

    clickEnter()
    testing.expect_value(t, 0, int(sync.atomic_load(&windowData.currentFileSearchTermIndex)))

    clickEsc()
    testing.expect(t, !sync.atomic_load(&windowData.isFileSearchOpen))
}

// save file, open it again, should be only one tab

@(test)
type_and_save :: proc(t: ^testing.T) {
    os.remove(main.editorStateFilePath)

    fileToSave :: "test1.txt"

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
        { windowRect.left + 30, windowRect.top + 150 },
    })

    time.sleep(2_000_000_000)

    typeStringOnKeyboard(windowData.parentHwnd, fileToSave)
    clickEnter()
    time.sleep(1_000_000_000)

    tab := main.getActiveTab()

    testing.expect(t, os.is_file(tab.filePath), "file was not created")
    
    saveFileContent, err := os.read_entire_file_from_filename_or_err(tab.filePath)
    testing.expect(t, err == nil, "could not read saved file")
    defer delete(saveFileContent)

    testing.expect_value(t, string(saveFileContent), text)

    os.remove(tab.filePath)
}

// @(test)
just_run_wait_and_close :: proc(t: ^testing.T) {
    os.remove(main.editorStateFilePath)

    appThread, windowData := startApp(proc(windowData: ^main.WindowData) -> bool {
        return windowData.windowCreated
    })
    defer stopApp(appThread, windowData.parentHwnd)

    time.sleep(5_000_000_000)
}
