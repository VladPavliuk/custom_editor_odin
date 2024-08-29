package main

import "core:fmt"
import "core:mem"

import win32 "core:sys/windows"

getTextFromClipboard :: proc(user_data: rawptr) -> (text: string, ok: bool) {
    assert(user_data != nil)

    hwnd := (^win32.HWND)(user_data)^

    if !IsClipboardFormatAvailable(WIN32_CF_UNICODETEXT) || !OpenClipboard(hwnd) {
        return
    }

    clipboardHandle := (win32.HGLOBAL)(GetClipboardData(WIN32_CF_UNICODETEXT))

    if uintptr(clipboardHandle) == uintptr(0) {
        return
    }

    globalMemory := GlobalLock(clipboardHandle)
    
	GlobalUnlock(clipboardHandle)
	CloseClipboard()

    textStr, err := win32.wstring_to_utf8(win32.wstring(globalMemory), -1)

    return textStr, err == nil
}

putTextIntoClipboard :: proc(user_data: rawptr, text: string) -> (ok: bool) {
    assert(user_data != nil)

    hwnd := (^win32.HWND)(user_data)^

    if !IsClipboardFormatAvailable(WIN32_CF_UNICODETEXT) {
        fmt.println("Clipboard is not available, error: ", win32.GetLastError())
        return false
    }

    if !OpenClipboard(hwnd) {
        fmt.println("Can't open clipboard, error: ", win32.GetLastError())
        return false
    }

    if !EmptyClipboard() {
        fmt.println("Can't empty clipboard, error: ", win32.GetLastError())
        return false
    }

    wideText: []u16
    wideTextLength: int
    if len(text) > 0 {
        wideText = win32.utf8_to_utf16(text)
        wideTextLength = 2 * (len(wideText) + 1)
    } else {
        emptyStr := []u16{ 0 }
        wideText = emptyStr[:]
        wideTextLength = 2
    }
    globalMemoryHandler := (win32.HGLOBAL)(win32.GlobalAlloc(win32.GMEM_MOVEABLE, uint(wideTextLength)))

    globalMemory := GlobalLock(globalMemoryHandler)
    
    mem.copy(globalMemory, raw_data(wideText), wideTextLength)

    GlobalUnlock(globalMemoryHandler)
    SetClipboardData(WIN32_CF_UNICODETEXT, (win32.HANDLE)(globalMemoryHandler))

    return CloseClipboard()
}