package tests

import "base:intrinsics"
import "base:runtime"
import "core:sync"
import "core:thread"
import "core:time"

import win32 "core:sys/windows"

foreign import user32 "system:user32.lib"

WIN32_CWPSTRUCT :: struct {
    lParam: win32.LPARAM,
    wParam: win32.WPARAM,
    message: win32.UINT,
    hwnd: win32.HWND,
}

@(default_calling_convention = "std")
foreign user32 {
    @(link_name="GetWindowThreadProcessId") GetWindowThreadProcessId :: proc(win32.HWND, win32.LPDWORD) ---
}

import main "../"

appWinHook: win32.HHOOK
isAppActive: bool = true

startApp :: proc(whenReady: proc (^$T) -> bool) -> (^thread.Thread, ^T) {
    appThread := thread.create_and_start(main.main, context)

    hwnd: win32.HWND = nil

    for hwnd == nil {
        wndClassName := win32.utf8_to_wstring("class")
        hwnd = win32.FindWindowW(wndClassName, nil)
    }

    // windowDataPtr := uintptr(win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA))

    // assert(windowDataPtr != 0, "Window related data must be defined")

    // windowData := (^T)(windowDataPtr)

    for !whenReady(&main.windowData) {}

    appWinHook = win32.SetWindowsHookExW(win32.WH_CALLWNDPROC, appWinHookCallback, nil, u32(appThread.id))

    // threadId: u32
    // GetWindowThreadProcessId(hwnd, &threadId)

    return appThread, &main.windowData
}

stopApp :: proc(appThread: ^thread.Thread, hwnd: win32.HWND) {
    win32.UnhookWindowsHookEx(appWinHook)

    win32.SendMessageW(hwnd, win32.WM_DESTROY, 0, 0)

    //win32.DestroyWindow(hwnd)
    for !thread.is_done(appThread) { }

    thread.join(appThread)
    thread.destroy(appThread)
}

appWinHookCallback :: proc "stdcall" (code: win32.c_int, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    context = runtime.default_context()
    
    if code == 0 {
        event := (^WIN32_CWPSTRUCT)(uintptr(lParam))

        switch event.message {
        case win32.WM_ACTIVATE:
            sync.atomic_store(&isAppActive, event.wParam == 1)
        case win32.WM_ACTIVATEAPP:
            sync.atomic_store(&isAppActive, event.wParam == 1)
        }
    }

    return win32.CallNextHookEx(appWinHook, code, wParam, lParam)
}

stopIfAppNotActive :: proc() {
    if !sync.atomic_load(&isAppActive) { panic("App lost focus!") }
}

typeStringOnKeyboard :: proc(hwnd: win32.HWND, stringToType: string) {
    for char in stringToType {
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
    stopIfAppNotActive()
    
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
        },
    }

    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
}

moveMouse :: proc(x, y: i32) {
    stopIfAppNotActive()

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
        },
    }

    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
}

typeSymbol :: proc(hwnd: win32.HWND, symbol: rune) {
    char := u16(symbol)

    if char >= 97 && char <= 122 {
        char -= 32
    }

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

    time.sleep(10_000_000) // if it's less then 1ms, then it seems it's iggnored?
    stopIfAppNotActive()

    win32.SendInput(u32(len(input)), raw_data(input[:]), size_of(win32.INPUT))
}

clickEnter :: proc() {
    stopIfAppNotActive()

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