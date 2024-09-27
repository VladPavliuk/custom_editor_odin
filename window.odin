package main

import "core:strings"
import "core:text/edit"

import win32 "core:sys/windows"

UiContext :: struct {
    zIndex: f32,

    hotId: uiId,
    prevHotId: uiId,
    hotIdChanged: bool,
    tmpHotId: uiId,

    activeId: uiId,
    
    prevFocusedId: uiId,
    focusedId: uiId,
    focusedIdChanged: bool,
    tmpFocusedId: uiId,

    textInputCtx: EditableTextContext,

    scrollableElements: [dynamic]map[uiId]struct{},
    
    parentPositionsStack: [dynamic]int2,

    activeAlert: ^UiAlert,
}

InputState :: struct {
    deltaMousePosition: int2,
    mousePosition: int2,
    isLeftMouseButtonDown: bool,
    wasLeftMouseButtonDown: bool,
    wasLeftMouseButtonUp: bool,
    scrollDelta: i32,
}

inputState: InputState

EditableTextContext :: struct {
    text: strings.Builder,
    rect: Rect,
    leftOffset: i32,

    editorState: edit.State,
    disableNewLines: bool,
    maxLineWidth: f32,

    lineIndex: i32, // top line index from which text is rendered
    cursorLineIndex: i32,
    cursorLeftOffset: f32, // offset from line start
    lines: [dynamic]int2,

    //TODO: probabyly put word wrapping property here
}

FileTab :: struct {
    name: string,
    ctx: ^EditableTextContext,
    filePath: string, // path to actual file that mapped to the tab
    isSaved: bool,
}

WindowData :: struct {
    windowCreated: bool,
    parentHwnd: win32.HWND,

    delta: f64,
    size: int2,

    uiContext: UiContext,

    wasInputSymbolTyped: bool, // distingushed between symbols on keyboard and control keys like backspace, delete, etc.

    maxZIndex: f32,

    font: FontData,

    isInputMode: bool,

    editorPadding: Rect,

    editableTextCtx: ^EditableTextContext,

    fileTabs: [dynamic]FileTab,
    activeFileTab: i32,

    explorer: ^Explorer,

    //> settings
    wordWrapping: bool,
    //<
}

windowData: WindowData

createWindow :: proc(size: int2) {
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
        nil,
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
    windowData.parentHwnd = hwnd

    windowData.editorPadding = { top = 50, bottom = 15, left = 50, right = 15 }

    if !applyPreviousFileTabs() {
        addEmptyTab() // if no previous file tabs found, create an empty one
    }

    windowData.isInputMode = true

    windowData.maxZIndex = 100.0

    //> default settings
    windowData.wordWrapping = false
    //<

    // set default editable context
    switchInputContextToEditor()

    // TODO: testing
    windowData.uiContext.textInputCtx.text = strings.builder_make()
    strings.write_string(&windowData.uiContext.textInputCtx.text, "HYI")
    //<

    windowData.windowCreated = true
}

getActiveTab :: proc() -> ^FileTab {
    return &windowData.fileTabs[windowData.activeFileTab]
}

getActiveTabContext :: proc() -> ^EditableTextContext {
    return getActiveTab().ctx
}

addEmptyTab :: proc() {
    initFileCtx := createEmptyTextContext()
    tab := FileTab{
        name = "(empty)",
        ctx = initFileCtx,
        isSaved = true,
    }
    append(&windowData.fileTabs, tab)

    windowData.activeFileTab = i32(len(windowData.fileTabs) - 1) // switch to new tab

    switchInputContextToEditor()
}

moveToNextTab :: proc() {
    windowData.activeFileTab = (windowData.activeFileTab + 1) % i32(len(windowData.fileTabs))
    switchInputContextToEditor()
}

moveToPrevTab :: proc() {
    windowData.activeFileTab = windowData.activeFileTab == 0 ? i32(len(windowData.fileTabs) - 1) : windowData.activeFileTab - 1

    switchInputContextToEditor()
}

tryCloseFileTab :: proc(index: i32) {
    tab := &windowData.fileTabs[index]

    // if there's any unsaved changes, show confirmation box
    if !tab.isSaved {
        result := win32.MessageBoxW(
            windowData.parentHwnd,
            win32.utf8_to_wstring("Do you want to save the changes?"),
            win32.utf8_to_wstring("Edi the editor"),
            win32.MB_YESNOCANCEL | win32.MB_ICONWARNING,
        )

        switch result {
        case win32.IDYES:
            saveToOpenedFile(tab)
        case win32.IDNO:
        case win32.IDCANCEL, win32.IDCLOSE:
            return
        }
    }

    freeTextContext(tab.ctx)
    ordered_remove(&windowData.fileTabs, index)
    windowData.activeFileTab = index == 0 ? index : index - 1

    if len(windowData.fileTabs) == 0 {
        addEmptyTab()
    }

    switchInputContextToEditor()
}

createEmptyTextContext :: proc() -> ^EditableTextContext {
    ctx := new(EditableTextContext)
    ctx.text = strings.builder_make(0)
    ctx.rect = Rect{
        top = windowData.size.y / 2 - windowData.editorPadding.top,
        bottom = -windowData.size.y / 2 + windowData.editorPadding.bottom,
        left = -windowData.size.x / 2 + windowData.editorPadding.left,
        right = windowData.size.x / 2 - windowData.editorPadding.right,
    }

    edit.init(&ctx.editorState, context.allocator, context.allocator)
    edit.setup_once(&ctx.editorState, &ctx.text)
    ctx.editorState.selection = { 0, 0 }

    ctx.editorState.set_clipboard = putTextIntoClipboard
    ctx.editorState.get_clipboard = getTextFromClipboard
    ctx.editorState.clipboard_user_data = &windowData.parentHwnd

    return ctx
}

freeTextContext :: proc(ctx: ^EditableTextContext) {
    delete(ctx.lines)
    edit.destroy(&ctx.editorState)
    strings.builder_destroy(&ctx.text)
    free(ctx)
}

removeWindowData :: proc() {
    for _, kerning in windowData.font.kerningTable {
        delete(kerning)
    }
    delete(windowData.font.kerningTable)
    delete(windowData.font.chars)

    for tab in windowData.fileTabs {
        freeTextContext(tab.ctx)
    }
    delete(windowData.fileTabs)

    delete(windowData.uiContext.scrollableElements)
    delete(windowData.uiContext.parentPositionsStack)
    delete(windowData.uiContext.textInputCtx.lines)
    edit.destroy(&windowData.uiContext.textInputCtx.editorState)
    strings.builder_destroy(&windowData.uiContext.textInputCtx.text)
    clearExplorer(windowData.explorer)

    // TODO: investigate, is this code block is needed
    //>
    win32.DestroyWindow(windowData.parentHwnd)

    res := win32.UnregisterClassW(win32.utf8_to_wstring("class"), win32.HINSTANCE(win32.GetModuleHandleA(nil)))
    assert(bool(res), fmt.tprintfln("Error: %i", win32.GetLastError()))
    //<

    windowData = {}
}

getEditorSize :: proc() -> int2 {
    return {
        windowData.size.x - windowData.editorPadding.left - windowData.editorPadding.right,
        windowData.size.y - windowData.editorPadding.top - windowData.editorPadding.bottom,
    }
}

switchInputContextToUiElement :: proc(rect: Rect, disableNewLines: bool) {
    windowData.editableTextCtx = &windowData.uiContext.textInputCtx

    windowData.editableTextCtx.disableNewLines = disableNewLines
    windowData.editableTextCtx.rect = rect
    ctx := windowData.editableTextCtx

    edit.init(&ctx.editorState, context.allocator, context.allocator)
    edit.setup_once(&ctx.editorState, &ctx.text)
    ctx.editorState.selection = { 0, 0 }

    ctx.editorState.set_clipboard = putTextIntoClipboard
    ctx.editorState.get_clipboard = getTextFromClipboard
    ctx.editorState.clipboard_user_data = &windowData.parentHwnd
}

switchInputContextToEditor :: proc() {
    windowData.editableTextCtx = getActiveTabContext() 
}

isActiveTabContext :: proc() -> bool {
    return windowData.editableTextCtx == getActiveTab().ctx
}

tryCloseEditor :: proc() {
    // is any tab that has unsaved changes
    // hasUnsavedChanges := false
    // for tab in windowData.fileTabs {
    //     if !tab.isSaved { 
    //         hasUnsavedChanges = true
    //         break
    //     }
    // }

    win32.DestroyWindow(windowData.parentHwnd)
}