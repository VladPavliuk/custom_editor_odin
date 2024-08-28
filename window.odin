package main

import "base:runtime"
import "core:strings"
import "core:text/edit"
import "core:os"
import "core:mem"
import "core:fmt"

import "vendor:directx/d3d11"
import "core:unicode/utf16"

import win32 "core:sys/windows"

foreign import user32 "system:user32.lib"
foreign import kernel32 "system:kernel32.lib"

WM_UAHDRAWMENU :: 0x0091

@(default_calling_convention = "std")
foreign user32 {
	@(link_name="CreateMenu") CreateMenu :: proc() -> win32.HMENU ---
	@(link_name="DrawMenuBar") DrawMenuBar :: proc(win32.HWND) ---
	@(link_name="IsClipboardFormatAvailable") IsClipboardFormatAvailable :: proc(uint) -> bool ---
	@(link_name="OpenClipboard") OpenClipboard :: proc(win32.HWND) -> bool ---
	@(link_name="EmptyClipboard") EmptyClipboard :: proc() -> bool ---
	@(link_name="SetClipboardData") SetClipboardData :: proc(uint, win32.HANDLE) -> win32.HANDLE ---
	@(link_name="GetClipboardData") GetClipboardData :: proc(uint) -> win32.HANDLE ---
	@(link_name="CloseClipboard") CloseClipboard :: proc() -> bool ---
    @(link_name="GlobalLock") GlobalLock :: proc(win32.HGLOBAL) -> win32.LPVOID ---
    @(link_name="GlobalUnlock") GlobalUnlock :: proc(win32.HGLOBAL) -> bool ---
    @(link_name="GetMenuBarInfo") GetMenuBarInfo :: proc(win32.HWND, u64, win32.LONG, ^WIN32_MENUBARINFO) -> bool ---
    // @(link_name="CallWndProc") CallWndProc :: proc(int, win32.WPARAM, win32.LPARAM) -> win32.LRESULT ---
}

WIN32_OBJID_MENU :: 0xFFFFFFFD

WIN32_MENUBARINFO :: struct #packed {
    cbSize: win32.DWORD,
    rcBar: win32.RECT,
    hMenu: win32.HMENU,
    hwndMenu: win32.HWND,
    fBarFocused: i32,
    fFocused: i32,
    fUnused: i32,
} 

get_WIN32_MENUBARINFO :: proc() -> WIN32_MENUBARINFO {
    return WIN32_MENUBARINFO{
        cbSize = size_of(WIN32_MENUBARINFO),
        fBarFocused = 1,
        fFocused = 1,
        fUnused = 30,
    }
}

WIN32_CF_TEXT :: 1
WIN32_CF_UNICODETEXT :: 13

IDM_FILE_NEW :: 1
IDM_FILE_OPEN :: 2
IDM_FILE_SAVE :: 3
IDM_FILE_SAVE_AS :: 4
IDM_FILE_QUIT :: 5

IDI_ICON :: 101 // copied from resources/resource.rc file

ScreenGlyphs :: struct {
    lineIndex: i32, // top line index from which text is rendered
    cursorLineIndex: i32,
    lines: [dynamic]int2, // { start line char index, end char line index }
}

WindowData :: struct {
    windowCreated: bool,
    parentHwnd: win32.HWND,

    size: int2,

    openedFilePath: string,

    mousePosition: float2,
    isLeftMouseButtonDown: bool,
    wasLeftMouseButtonDown: bool,
    wasLeftMouseButtonUp: bool,

    wasInputSymbolTyped: bool, // distingushed between symbols on keyboard and control keys like backspace, delete, etc.

    directXState: ^DirectXState,

    font: FontData,

    isInputMode: bool,
    testInputString: strings.Builder,
    inputState: edit.State,
    screenGlyphs: ScreenGlyphs,
}

createWindow :: proc(size: int2) -> ^WindowData {
    hInstance := win32.HINSTANCE(win32.GetModuleHandleA(nil))
    
    // classNameBuffer: [255]u16
    // utf16.encode_string(classNameBuffer[:], "class_1")
    wndClassName := win32.utf8_to_wstring("class")
    // test := "class 1"
    // wndClassName := cast([^]u16)raw_data(test)
    
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
        win32.WS_OVERLAPPEDWINDOW,
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

    clientRect: win32.RECT
    win32.GetClientRect(hwnd, &clientRect)

    windowData.size = { clientRect.right - clientRect.left, clientRect.bottom - clientRect.top }
    
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

    windowData.testInputString = strings.builder_make()

    windowData.screenGlyphs.lineIndex = 0
    // fileContent := os.read_entire_file_from_filename("../test_text_file.txt") or_else panic("Failed to read file")
    // originalFileText := string(fileContent[:])
   
    // //TODO: add handling Window's \r\n staff
    // testText, wasNewAllocation := strings.remove_all(originalFileText, "\r")

    // if wasNewAllocation {
    //     delete(fileContent)
    // }

    // strings.write_string(&windowData.testInputString, testText)
    
    edit.init(&windowData.inputState, context.allocator, context.allocator)
    edit.setup_once(&windowData.inputState, &windowData.testInputString)
    windowData.inputState.selection = { 0, 0 }

    windowData.inputState.set_clipboard = putTextIntoClipboard
    windowData.inputState.get_clipboard = getTextFromClipboard
    windowData.inputState.clipboard_user_data = &windowData.parentHwnd

    windowData.parentHwnd = hwnd

    windowData.isInputMode = true

    return windowData
}

removeWindowData :: proc(windowData: ^WindowData) {
    for glyph, kerning in windowData.font.kerningTable {
        delete(kerning)
    }
    delete(windowData.font.kerningTable)
    delete(windowData.font.chars)

    delete(windowData.screenGlyphs.lines)
    edit.destroy(&windowData.inputState)
    strings.builder_destroy(&windowData.testInputString)

    win32.DestroyWindow(windowData.parentHwnd)

    // classNameBuffer: [255]u16
    // utf16.encode_string(classNameBuffer[:], "class_1")
    // res := win32.UnregisterClassW(raw_data(classNameBuffer[:]), win32.HINSTANCE(win32.GetModuleHandleA(nil)))
    // assert(bool(res), fmt.tprintfln("Error: %i", win32.GetLastError()))
    //test4 := win32.GetLastError()

    res := win32.UnregisterClassW(win32.utf8_to_wstring("class"), win32.HINSTANCE(win32.GetModuleHandleA(nil)))
    assert(bool(res), fmt.tprintfln("Error: %i", win32.GetLastError()))

    free(windowData)
}

winProc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    context = runtime.default_context()
    getWindowData := proc(hwnd: win32.HWND) -> ^WindowData { return (^WindowData)(uintptr(win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA))) }

    switch msg {
    case win32.WM_NCCREATE:
        windowData := (^WindowData)(((^win32.CREATESTRUCTW)(uintptr(lParam))).lpCreateParams)

        win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, win32.LONG_PTR(uintptr(windowData)))
    case win32.WM_MOUSEMOVE:
        windowData := getWindowData(hwnd)

	    xMouse := win32.GET_X_LPARAM(lParam)
		yMouse := win32.GET_Y_LPARAM(lParam)

        windowData.mousePosition = { f32(xMouse), f32(yMouse) }

        windowData.mousePosition.x = max(0, windowData.mousePosition.x)
        windowData.mousePosition.y = max(0, windowData.mousePosition.y)

        windowData.mousePosition.x = min(f32(windowData.size.x), windowData.mousePosition.x)
        windowData.mousePosition.y = min(f32(windowData.size.y), windowData.mousePosition.y)
    case win32.WM_LBUTTONDOWN:
        windowData := getWindowData(hwnd)

		windowData.isLeftMouseButtonDown = true
		windowData.wasLeftMouseButtonDown = true

		win32.SetCapture(hwnd)
    case win32.WM_LBUTTONUP:
        windowData := getWindowData(hwnd)

        windowData.isLeftMouseButtonDown = false
        windowData.wasLeftMouseButtonUp = true

        // NOTE: We have to release previous capture, because we won't be able to use windws default buttons on the window
        win32.ReleaseCapture()
    case win32.WM_SIZE:
        windowData := getWindowData(hwnd)

        if !windowData.windowCreated { break }

        if wParam == win32.SIZE_MINIMIZED { break }

        clientRect: win32.RECT
        win32.GetClientRect(hwnd, &clientRect)

        windowSizeChangedHandler(windowData, clientRect.right - clientRect.left, clientRect.bottom - clientRect.top)

        // NOTE: while resizing we only get resize message, so we can't redraw from main loop, so we do it explicitlly
        render(windowData.directXState, windowData)
    case win32.WM_KEYDOWN:
        handle_WM_KEYDOWN(lParam, wParam, getWindowData(hwnd))
    case win32.WM_CHAR:
        windowData := getWindowData(hwnd)

        if windowData.wasInputSymbolTyped && windowData.isInputMode {
            edit.input_rune(&windowData.inputState, rune(wParam))
        }
    case win32.WM_MOUSEWHEEL:
        windowData := getWindowData(hwnd)

        yoffset := win32.GET_WHEEL_DELTA_WPARAM(wParam)

        if yoffset > 10 && windowData.screenGlyphs.lineIndex > 0 {
            windowData.screenGlyphs.lineIndex -= 1
        } else if yoffset < -10 {
            windowData.screenGlyphs.lineIndex += 1
        }
    case win32.WM_COMMAND:        
        windowData := getWindowData(hwnd)

		menuItemId := win32.LOWORD(u32(wParam))

        switch menuItemId {
        case IDM_FILE_OPEN:
            filePath, ok := ShowOpenFileDialog(windowData)
            if !ok { break }

            windowData.openedFilePath = filePath
            fileContent := os.read_entire_file_from_filename(filePath) or_else panic("Failed to read file")
            originalFileText := string(fileContent[:])
        
            testText, wasNewAllocation := strings.remove_all(originalFileText, "\r")

            if wasNewAllocation {
                delete(fileContent)
            }

            strings.builder_reset(&windowData.testInputString)

            strings.write_string(&windowData.testInputString, testText)
            
            edit.init(&windowData.inputState, context.allocator, context.allocator)
            edit.setup_once(&windowData.inputState, &windowData.testInputString)
            windowData.inputState.selection = { 0, 0 }
            windowData.screenGlyphs.lineIndex = 0
        case IDM_FILE_SAVE_AS:
            ok := ShowSaveAsFileDialog(windowData)

            if !ok { break }
        case IDM_FILE_SAVE:
            SaveToOpenedFile(windowData)
        }
    // case WM_UAHDRAWMENU:
    //     // win32.UAHMENU
    //     menuInfo := get_WIN32_MENUBARINFO()

    //     GetMenuBarInfo(hwnd, WIN32_OBJID_MENU, 0, &menuInfo)
        
    //     rcWindow: win32.RECT
    //     win32.GetWindowRect(hwnd, &rcWindow)

    //     rc := menuInfo.rcBar
    //     win32.OffsetRect(&rc, -rcWindow.left, -rcWindow.top)

    //     rc.top -= 1

    //     test := win32.CreateSolidBrush(win32.RGB(0,255,0))
    //     hdc := win32.GetDC(hwnd)

    //     win32.FillRect(hdc, &rc, test)
    //     win32.DeleteObject(win32.HGDIOBJ(test))
    //     win32.ReleaseDC(hwnd, hdc)

    //     break
    case win32.WM_DESTROY:
        win32.PostQuitMessage(0)
    // case win32.WM_ACTIVATEAPP:
        // win32.SendMessageA(hwnd, 1, 0, 0)
        // fmt.println(wParam, lParam)
    }

    return win32.DefWindowProcA(hwnd, msg, wParam, lParam)
}

SaveToOpenedFile :: proc(windowData: ^WindowData) -> (success: bool) {
    if len(windowData.openedFilePath) > 0 {
        err := os.write_entire_file_or_err(windowData.openedFilePath, windowData.testInputString.buf[:])
        assert(err == nil)
    } else {
        ShowSaveAsFileDialog(windowData)
    }

    return true
}

ShowSaveAsFileDialog :: proc(windowData: ^WindowData) -> (success: bool) {
    hr := win32.CoInitializeEx(nil, win32.COINIT(0x2 | 0x4))
    assert(hr == 0)
    defer win32.CoUninitialize()

    pFileSave: ^win32.IFileSaveDialog
    hr = win32.CoCreateInstance(win32.CLSID_FileSaveDialog, nil, 
        win32.CLSCTX_INPROC_SERVER | win32.CLSCTX_INPROC_HANDLER | win32.CLSCTX_LOCAL_SERVER | win32.CLSCTX_REMOTE_SERVER, 
        win32.IID_IFileSaveDialog, 
        cast(^win32.LPVOID)(&pFileSave))
    assert(hr == 0)
    defer pFileSave->Release()

    hr = pFileSave->Show(windowData.parentHwnd)
    if hr != 0 { return false }

    shellItem: ^win32.IShellItem
    pFileSave->GetResult(&shellItem)
    defer shellItem->Release()

    filePathW: win32.LPWSTR
    shellItem->GetDisplayName(win32.SIGDN.FILESYSPATH, &filePathW)
    defer win32.CoTaskMemFree(filePathW)

    filePath, _ := win32.wstring_to_utf8(filePathW, -1)

    err := os.write_entire_file_or_err(filePath, windowData.testInputString.buf[:])
    assert(err == nil)

    windowData.openedFilePath = filePath

    return true
}

ShowOpenFileDialog :: proc(windowData: ^WindowData) -> (res: string, success: bool) {
    hr := win32.CoInitializeEx(nil, win32.COINIT(0x2 | 0x4))
    assert(hr == 0)
    defer win32.CoUninitialize()

    pFileOpen: ^win32.IFileOpenDialog
    hr = win32.CoCreateInstance(win32.CLSID_FileOpenDialog, nil, 
        win32.CLSCTX_INPROC_SERVER | win32.CLSCTX_INPROC_HANDLER | win32.CLSCTX_LOCAL_SERVER | win32.CLSCTX_REMOTE_SERVER, 
        win32.IID_IFileOpenDialog, 
        cast(^win32.LPVOID)(&pFileOpen))
    assert(hr == 0)
    defer pFileOpen->Release()

    fileTypes: []win32.COMDLG_FILTERSPEC = {
        { win32.utf8_to_wstring("All Files"), win32.utf8_to_wstring("*") },
        { win32.utf8_to_wstring("Text files (*.txt | *.odin)"), win32.utf8_to_wstring("*.txt;*.odin") },
    }

    hr = pFileOpen->SetFileTypes(u32(len(fileTypes)), raw_data(fileTypes[:]))
    assert(hr == 0)

    hr = pFileOpen->Show(windowData.parentHwnd)
    if hr != 0 { return }

    pItem: ^win32.IShellItem
    hr = pFileOpen->GetResult(&pItem)
    assert(hr == 0)
    defer pItem->Release()

    pszFilePath: ^u16
    hr = pItem->GetDisplayName(win32.SIGDN.FILESYSPATH, &pszFilePath)
    assert(hr == 0)
    defer win32.CoTaskMemFree(pszFilePath)
    
    resStr, err := win32.wstring_to_utf8(win32.wstring(pszFilePath), -1)

    return resStr, err == nil
}

@(private="file") 
isShiftPressed :: proc() -> bool {
    return uint(win32.GetKeyState(win32.VK_SHIFT)) & 0x8000 == 0x8000
}

@(private="file") 
isCtrlPressed :: proc() -> bool {
    return uint(win32.GetKeyState(win32.VK_LCONTROL)) & 0x8000 == 0x8000
}

handle_WM_KEYDOWN :: proc(lParam: win32.LPARAM, wParam: win32.WPARAM, windowData: ^WindowData) {
    windowData.wasInputSymbolTyped = false
    
    if !isCtrlPressed() {
        isValidSymbol := false

        validInputSymbols := []int{
            win32.VK_SPACE,
            win32.VK_OEM_PLUS,
            win32.VK_OEM_COMMA,
            win32.VK_OEM_MINUS,
            win32.VK_OEM_PERIOD,
            win32.VK_OEM_1, // ;:
            win32.VK_OEM_2, // /?
            win32.VK_OEM_3, // `~
            win32.VK_OEM_4, // [{
            win32.VK_OEM_5, // \|
            win32.VK_OEM_6, // ]}
            win32.VK_OEM_7, // '"
            win32.VK_ADD,
            win32.VK_SUBTRACT,
            win32.VK_MULTIPLY,
            win32.VK_DIVIDE,
            win32.VK_DECIMAL,
        }
        
        for symbol in validInputSymbols {
            if symbol == int(wParam) {
                isValidSymbol = true
                break
            }
        }

        isValidSymbol = isValidSymbol || wParam >= 0x60 && wParam <= 0x69 // numpad
        isValidSymbol = isValidSymbol || wParam >= 0x41 && wParam <= 0x5A || wParam >= 0x30 && wParam <= 0x39

        windowData.wasInputSymbolTyped = isValidSymbol

        if isValidSymbol { return }
    }

    switch wParam {
    case win32.VK_RETURN:
        // NOTE: if there's any whitespace at the beginning of the line, copy it to the new line
        lineStart := windowData.inputState.line_start
        whiteSpacesCount := 0
        for i in lineStart..<windowData.inputState.line_end {
            char := windowData.testInputString.buf[i]

            if char != ' ' && char != '\t' {
                break
            }
            whiteSpacesCount += 1
        }

        edit.perform_command(&windowData.inputState, edit.Command.New_Line)

        if whiteSpacesCount > 0 {
            edit.input_text(&windowData.inputState, string(windowData.testInputString.buf[lineStart:][:whiteSpacesCount]))
        }
    case win32.VK_TAB:
        edit.input_rune(&windowData.inputState, rune('\t'))
    case win32.VK_LEFT:
        if isCtrlPressed() {
            if isShiftPressed() {
                edit.perform_command(&windowData.inputState, edit.Command.Select_Word_Left)
            } else {
                edit.move_to(&windowData.inputState, edit.Translation.Word_Left)
            }
        } else {
            if isShiftPressed() {
                edit.perform_command(&windowData.inputState, edit.Command.Select_Left)
            } else {
                edit.move_to(&windowData.inputState, edit.Translation.Left)
            }
        }
    case win32.VK_RIGHT:
        if isCtrlPressed() {
            if isShiftPressed() {
                edit.perform_command(&windowData.inputState, edit.Command.Select_Word_Right)
            } else {
                edit.move_to(&windowData.inputState, edit.Translation.Word_Right)
            }
        } else {
            if isShiftPressed() {
                edit.perform_command(&windowData.inputState, edit.Command.Select_Right)
            } else {
                edit.move_to(&windowData.inputState, edit.Translation.Right)
            }
        }
    case win32.VK_UP:
        if windowData.screenGlyphs.cursorLineIndex <= windowData.screenGlyphs.lineIndex && 
            windowData.screenGlyphs.lineIndex > 0 {
            windowData.screenGlyphs.lineIndex -= 1
        }

        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Up)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Up)
        }
    case win32.VK_DOWN:
        maxLinesOnScreen := i32(f32(windowData.size.y) / windowData.font.lineHeight)

        if windowData.screenGlyphs.cursorLineIndex >= windowData.screenGlyphs.lineIndex + maxLinesOnScreen - 1 {
            windowData.screenGlyphs.lineIndex += 1
            // windowData.screenGlyphs.lineIndex = max(windowData.screenGlyphs.lineIndex + maxLinesOnScreen, windowData.screenGlyphs.lineIndex)
        }

        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Down)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Down)
        }
    case win32.VK_BACK:
        if isCtrlPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Delete_Word_Left)
        } else {
            edit.perform_command(&windowData.inputState, edit.Command.Backspace)
        }
    case win32.VK_DELETE:
        if isCtrlPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Delete_Word_Right)
        } else {
            edit.perform_command(&windowData.inputState, edit.Command.Delete)
        }
    case win32.VK_HOME:
        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Line_Start)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_Start)
        }
    case win32.VK_END:
        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Line_End)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_End)
        }
    case win32.VK_A:
        edit.perform_command(&windowData.inputState, edit.Command.Select_All)
    case win32.VK_C:
        edit.perform_command(&windowData.inputState, edit.Command.Copy)
    case win32.VK_V:
        edit.perform_command(&windowData.inputState, edit.Command.Paste)
    case win32.VK_X:
        edit.perform_command(&windowData.inputState, edit.Command.Cut)
    case win32.VK_Z:
        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Redo)
        } else {
            edit.perform_command(&windowData.inputState, edit.Command.Undo)
        }
    case win32.VK_S:
        SaveToOpenedFile(windowData)
    }
}

windowSizeChangedHandler :: proc "c" (windowData: ^WindowData, width, height: i32) {
    context = runtime.default_context()

    windowData.size = { width, height }
    directXState := windowData.directXState

    directXState.ctx->OMSetRenderTargets(0, nil, nil)
    directXState.backBufferView->Release()
    directXState.backBuffer->Release()
    directXState.depthBufferView->Release()
    directXState.depthBuffer->Release()

    directXState.ctx->Flush()
    directXState.swapchain->ResizeBuffers(2, u32(width), u32(height), .R8G8B8A8_UNORM, {})

	res := directXState.swapchain->GetBuffer(0, d3d11.ITexture2D_UUID, (^rawptr)(&directXState.backBuffer))
    assert(res == 0)

	res = directXState.device->CreateRenderTargetView(directXState.backBuffer, nil, &directXState.backBufferView)
    assert(res == 0)

    depthBufferDesc: d3d11.TEXTURE2D_DESC
	directXState.backBuffer->GetDesc(&depthBufferDesc)
    depthBufferDesc.Format = .D24_UNORM_S8_UINT
	depthBufferDesc.BindFlags = {.DEPTH_STENCIL}

	res = directXState.device->CreateTexture2D(&depthBufferDesc, nil, &directXState.depthBuffer)
    assert(res == 0)

	res = directXState.device->CreateDepthStencilView(directXState.depthBuffer, nil, &directXState.depthBufferView)
    assert(res == 0)

    viewport := d3d11.VIEWPORT{
        0, 0,
        f32(depthBufferDesc.Width), f32(depthBufferDesc.Height),
        0, 1,
    }

    directXState.ctx->RSSetViewports(1, &viewport)

    viewMatrix := getOrthoraphicsMatrix(f32(width), f32(height), 0.1, 10.0)

    updateGpuBuffer(&viewMatrix, directXState.constantBuffers[.PROJECTION], directXState)
}

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