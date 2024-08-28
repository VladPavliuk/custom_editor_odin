package tests

import "base:intrinsics"
import "core:testing"
import "core:sync"
import "core:thread"
import "core:log"
import "core:strings"
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

startApp :: proc() -> (^thread.Thread, ^main.WindowData) {
    windowData: ^main.WindowData
    wasWindowCreated := false
    // fileContent := os.read_entire_file_from_filename_or_err("../test_text_file.txt") or_else panic("Error while reading file")

    appThread := thread.create_and_start_with_poly_data2(&windowData, &wasWindowCreated, runApp, context)

    for !intrinsics.atomic_load(&wasWindowCreated) {}

    windowData = intrinsics.atomic_load(&windowData)

    return appThread, windowData
}

stopApp :: proc(appThread: ^thread.Thread, windowData: ^main.WindowData) {
    win32.SendMessageW(windowData.parentHwnd, win32.WM_DESTROY, 0, 0)

    for !thread.is_done(appThread) { }

    thread.join(appThread)
    thread.destroy(appThread)
}

typeStringOnKeyboard :: proc(hwnd: win32.HWND, stringToType: string) {
    for char in stringToType {
        time.sleep(1_000_000) // if it's less then 1ms, then it seems it's iggnored?
        typeSymbol(hwnd, char)        
    }
    
    time.sleep(1_000_000) // it seems that win32 is kind of parallel, so it's better to wait a bit to make sure that previous win32 calls are done 
}

clickMouse :: proc{clickMouse_Single, clickMouse_Multiple}

clickMouse_Multiple :: proc(points: [][2]i32) {
    for point in points {
        clickMouse_Single(point[0], point[1])        
    }
}

clickMouse_Single :: proc(x, y: i32) {
    screenX := f32(x) * 65536.0 / f32(win32.GetSystemMetrics(win32.SM_CXSCREEN))
    screenY := f32(y) * 65536.0 / f32(win32.GetSystemMetrics(win32.SM_CYSCREEN))

    input := []win32.INPUT {
        {
            type = win32.INPUT_TYPE.MOUSE,
            mi = win32.MOUSEINPUT{
                dx = win32.LONG(screenX),
                dy = win32.LONG(screenY),
                dwFlags = 0x0001 | 0x0002 | 0x8000, // MOUSEEVENTF_MOVE | MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_ABSOLUTE
            },
        },
        {
            type = win32.INPUT_TYPE.MOUSE,
            mi = win32.MOUSEINPUT{
                dx = win32.LONG(screenX),
                dy = win32.LONG(screenY),
                dwFlags = 0x0001 | 0x0004 | 0x8000, // MOUSEEVENTF_MOVE | MOUSEEVENTF_LEFTUP | MOUSEEVENTF_ABSOLUTE
            },
        }
    }

    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
    // assert(res == 0, fmt.tprintfln("Error: %i", win32.GetLastError()))
}

moveMouse :: proc(x, y: i32) {
    screenX := f32(x) * 65536.0 / f32(win32.GetSystemMetrics(win32.SM_CXSCREEN))
    screenY := f32(y) * 65536.0 / f32(win32.GetSystemMetrics(win32.SM_CYSCREEN))

    input := []win32.INPUT {
        {
            type = win32.INPUT_TYPE.MOUSE,
            mi = win32.MOUSEINPUT{
                dx = win32.LONG(screenX),
                dy = win32.LONG(screenY),
                dwFlags = 0x0001 | 0x8000, // MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE
            },
        }
    }

    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
    // assert(res == 0, fmt.tprintfln("Error: %i", win32.GetLastError()))
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

clickEnter :: proc() {
    input := []win32.INPUT {
        {
            type = win32.INPUT_TYPE.KEYBOARD,
            ki = win32.KEYBDINPUT{
                wVk = win32.VK_RETURN,
                dwFlags = 0,
            },
        }, {
            type = win32.INPUT_TYPE.KEYBOARD,
            ki = win32.KEYBDINPUT{
                wVk = win32.VK_RETURN,
                dwFlags = 0x0002, // KEYEVENTF_KEYUP
            },
        },
    }

    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
}