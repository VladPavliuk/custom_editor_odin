package tests

import "base:intrinsics"
import "core:testing"
import "core:sync"
import "core:thread"
import "core:log"
// import "core:debug"
import "core:os"
import "core:fmt"
import "core:time"

import win32 "core:sys/windows"

import main "../"

runApp :: proc(windowDataPtr: ^^main.WindowData, wasWindowCreated: ^bool) {
    windowData := main.preCreateWindow()

    intrinsics.atomic_store(windowDataPtr, windowData)
    intrinsics.atomic_store(wasWindowCreated, true)
    // windowDataPtr^ = windowData
    // wasWindowCreated^ = true

    main.run(windowData)
}

typeStringOnKeyboard :: proc(hwnd: win32.HWND, stringToType: string) {
    for char in stringToType {
        time.sleep(1_000_000)
        typeSymbol(hwnd, char)        
    }
}

typeSymbol :: proc(hwnd: win32.HWND, symbol: rune) {
    char := u16(symbol)

    flags := 0
    // if char >= 33 && char <= 96 {}
    if char >= 97 && char <= 122 {
        char -= 32
        // flags
    }

    // win32.VK_SHIFT

    input := []win32.INPUT {
        {
            type = win32.INPUT_TYPE.KEYBOARD,
            ki = win32.KEYBDINPUT{
                wVk = char,
                dwFlags = 0,
            },
        }, {
            type = win32.INPUT_TYPE.KEYBOARD,
            ki = win32.KEYBDINPUT{
                wVk = char,
                dwFlags = 0x0002, // KEYEVENTF_KEYUP
            },
        },
    }
    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
    // 1638401
    // win32.SendMessageW(hwnd, win32.WM_KEYDOWN, (win32.WPARAM)(symbol), 2293761)
    // win32.SendMessageW(hwnd, win32.WM_CHAR, (win32.WPARAM)(symbol), 2293761)
}

@(test)
just_run_and_close :: proc(t: ^testing.T) {
    windowData: ^main.WindowData
    wasWindowCreated := false
    // fileContent := os.read_entire_file_from_filename_or_err("../test_text_file.txt") or_else panic("Error while reading file")

    app := thread.create_and_start_with_poly_data2(&windowData, &wasWindowCreated, runApp, context)

    for !intrinsics.atomic_load(&wasWindowCreated) {}

    windowData = intrinsics.atomic_load(&windowData)

    // typeStringOnKeyboard(windowData.parentHwnd, string(fileContent))
    text := "all work and no play makes jack a dull boy"

    for i in 0..<40 {
        typeStringOnKeyboard(windowData.parentHwnd, text)

    }

    win32.SendMessageW(windowData.parentHwnd, win32.WM_DESTROY, 0, 0)
    for !thread.is_done(app) { }

    thread.join(app)
    thread.destroy(app)
}
