package main

import "core:strings"
import "core:text/edit"
import "core:mem"
import "core:fmt"

import "core:unicode/utf16"

import win32 "core:sys/windows"

ScreenGlyphs :: struct {
    lineIndex: i32, // top line index from which text is rendered
    cursorLineIndex: i32,
    lines: [dynamic]int2, // { start line char index, end char line index }
}

WindowData :: struct {
    windowCreated: bool,
    parentHwnd: win32.HWND,

    size: int2,

    //> ui
    uiZIndex: f32,

    hotUiId: uiId,
    prevHotUiId: uiId,
    hotUiIdChanged: bool,
    tmpHotUiId: uiId,

    activeUiId: uiId,
    
    parentPositionsStack: [dynamic]int2,
    // verticalScrollTopOffset: i32,
    // testingScrollTopOffset: i32,
    // testPanelLocation: int2,

    //<

    openedFilePath: string,

    deltaMousePosition: int2,
    mousePosition: int2,
    isLeftMouseButtonDown: bool,
    wasLeftMouseButtonDown: bool,
    wasLeftMouseButtonUp: bool,

    wasInputSymbolTyped: bool, // distingushed between symbols on keyboard and control keys like backspace, delete, etc.

    directXState: ^DirectXState,
    maxZIndex: f32,

    font: FontData,

    isInputMode: bool,

    text: strings.Builder,
    editorPadding: Rect,

    inputState: edit.State,
    screenGlyphs: ScreenGlyphs,
}

createWindow :: proc(size: int2) -> ^WindowData {
    hInstance := win32.HINSTANCE(win32.GetModuleHandleA(nil))
    
    wndClassName := win32.utf8_to_wstring("class")
    
    resourceIcon := win32.LoadImageW(hInstance, win32.MAKEINTRESOURCEW(IDI_ICON), 
        win32.IMAGE_ICON, 256, 256, win32.LR_DEFAULTCOLOR)

    wndClass: win32.WNDCLASSEXW = {
        cbSize = size_of(win32.WNDCLASSEXW),
        hInstance = hInstance,
        lpszClassName = wndClassName,
        lpfnWndProc = winProc,
        style = win32.CS_DBLCLKS,
        hCursor = win32.LoadCursorA(nil, win32.IDC_ARROW),
        hIcon = (win32.HICON)(resourceIcon),
    }

    res := win32.RegisterClassExW(&wndClass)
   
    assert(res != 0, fmt.tprintfln("Error: %i", win32.GetLastError()))
    // defer win32.UnregisterClassW(wndClassName, hInstance)

    windowData := new(WindowData)
    mem.zero(windowData, size_of(WindowData))
    
    // TODO: is it good approach?
    win32.SetProcessDpiAwarenessContext(win32.DPI_AWARENESS_CONTEXT_SYSTEM_AWARE)
    
    // TODO: it won't work with utf-16 symbols in the title
    windowTitle := "Editor"
    
    hwnd := win32.CreateWindowExW(
        0,
        wndClassName,
        cast([^]u16)raw_data(windowTitle),
        win32.WS_OVERLAPPEDWINDOW | win32.CS_DBLCLKS,
        win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, 
        size.x, size.y,
        nil, nil,
        hInstance,
        windowData,
    )

    assert(hwnd != nil)

    //> set instance window show without fade in transition
    attrib: u32 = 1
    win32.DwmSetWindowAttribute(hwnd, u32(win32.DWMWINDOWATTRIBUTE.DWMWA_TRANSITIONS_FORCEDISABLED), &attrib, size_of(u32))
    //<

    //> set window dark mode
    attrib = 1
    win32.DwmSetWindowAttribute(hwnd, u32(win32.DWMWINDOWATTRIBUTE.DWMWA_USE_IMMERSIVE_DARK_MODE), &attrib, size_of(u32))
    darkColor: win32.COLORREF = 0x00505050
    win32.DwmSetWindowAttribute(hwnd, u32(win32.DWMWINDOWATTRIBUTE.DWMWA_BORDER_COLOR), &darkColor, size_of(win32.COLORREF))
    //<

    win32.ShowWindow(hwnd, win32.SW_SHOWDEFAULT)

    //> create top bar
    {
        windowMenubar := CreateMenu()
        windowFileMenu := CreateMenu()

        assert(windowMenubar != nil)
        assert(windowFileMenu != nil)
        
        wideStringBuffer: [255]u16

        utf16.encode_string(wideStringBuffer[:], "&File")
        win32.AppendMenuW(windowMenubar, win32.MF_POPUP, uintptr(windowFileMenu), raw_data(wideStringBuffer[:]))

        utf16.encode_string(wideStringBuffer[:], "&Open...")
        win32.AppendMenuW(windowFileMenu, win32.MF_STRING, IDM_FILE_OPEN, raw_data(wideStringBuffer[:]))
        
        utf16.encode_string(wideStringBuffer[:], "&Save")
        win32.AppendMenuW(windowFileMenu, win32.MF_STRING, IDM_FILE_SAVE, raw_data(wideStringBuffer[:]))
        
        utf16.encode_string(wideStringBuffer[:], "&Save as...")
        win32.AppendMenuW(windowFileMenu, win32.MF_STRING, IDM_FILE_SAVE_AS, raw_data(wideStringBuffer[:]))

        win32.SetMenu(hwnd, windowMenubar)
    }
    //<

    clientRect: win32.RECT
    win32.GetClientRect(hwnd, &clientRect)

    windowData.size = { clientRect.right - clientRect.left, clientRect.bottom - clientRect.top }

    windowData.editorPadding = { top = 10, bottom = 10, left = 50, right = 15 }

    windowData.text = strings.builder_make()

    windowData.screenGlyphs.lineIndex = 0
    // fileContent := os.read_entire_file_from_filename("../test_data/test_text_file.txt") or_else panic("Failed to read file")
    // originalFileText := string(fileContent[:])
   
    // //TODO: add handling Window's \r\n staff
    // testText, wasNewAllocation := strings.remove_all(originalFileText, "\r")

    // if wasNewAllocation {
    //     delete(fileContent)
    // }

    // strings.write_string(&windowData.text, testText)
    
    edit.init(&windowData.inputState, context.allocator, context.allocator)
    edit.setup_once(&windowData.inputState, &windowData.text)
    windowData.inputState.selection = { 0, 0 }

    windowData.inputState.set_clipboard = putTextIntoClipboard
    windowData.inputState.get_clipboard = getTextFromClipboard
    windowData.inputState.clipboard_user_data = &windowData.parentHwnd

    windowData.parentHwnd = hwnd

    windowData.isInputMode = true

    windowData.maxZIndex = 100.0
    windowData.windowCreated = true

    // createVerticalScrollBar(windowData)

    return windowData
}

// createVerticalScrollBar :: proc(windowData: ^WindowData) {
//     rect: win32.RECT

//     win32.GetClientRect(windowData.parentHwnd, &rect)

//     WIN32_SBS_HORZ :: 0x0000

//     sbHeight: i32 = 30
//     win32.CreateWindowExW(
//         0,
//         win32.utf8_to_wstring("SCROLLBAR"),
//         nil,
//         win32.WS_CHILD | win32.WS_VISIBLE | WIN32_SBS_HORZ,
//         rect.left,
//         rect.bottom - sbHeight, 
//         rect.right, 
//         sbHeight,
//         windowData.parentHwnd,
//         nil,
//         win32.HINSTANCE(win32.GetModuleHandleA(nil)),
//         nil,
//     )
// }

removeWindowData :: proc(windowData: ^WindowData) {
    for _, kerning in windowData.font.kerningTable {
        delete(kerning)
    }
    delete(windowData.font.kerningTable)
    delete(windowData.font.chars)

    delete(windowData.screenGlyphs.lines)
    edit.destroy(&windowData.inputState)
    strings.builder_destroy(&windowData.text)

    win32.DestroyWindow(windowData.parentHwnd)

    res := win32.UnregisterClassW(win32.utf8_to_wstring("class"), win32.HINSTANCE(win32.GetModuleHandleA(nil)))
    assert(bool(res), fmt.tprintfln("Error: %i", win32.GetLastError()))

    free(windowData)
}

getEditorSize :: proc(windowData: ^WindowData) -> int2 {
    return {
        windowData.size.x - windowData.editorPadding.left - windowData.editorPadding.right,
        windowData.size.y - windowData.editorPadding.top - windowData.editorPadding.bottom,
    }
}