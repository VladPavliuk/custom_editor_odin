package main

import "base:runtime"
import "core:os"
import "core:strings"
import "core:text/edit"
import "vendor:directx/d3d11"

import win32 "core:sys/windows"

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

        prevMousePosition := windowData.mousePosition
        windowData.mousePosition = { xMouse, yMouse }

        windowData.deltaMousePosition = windowData.mousePosition - prevMousePosition

        windowData.mousePosition.x = max(0, windowData.mousePosition.x)
        windowData.mousePosition.y = max(0, windowData.mousePosition.y)

        windowData.mousePosition.x = min(windowData.size.x, windowData.mousePosition.x)
        windowData.mousePosition.y = min(windowData.size.y, windowData.mousePosition.y)
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
    case win32.WM_LBUTTONDBLCLK:
        windowData := getWindowData(hwnd)

        // NOTE: for simplicity just pretend that WM_LBUTTONDBLCLK message is just WM_LBUTTONDOWN
		windowData.isLeftMouseButtonDown = true
		windowData.wasLeftMouseButtonDown = true
        
		win32.SetCapture(hwnd)
    case win32.WM_SIZE:
        windowData := getWindowData(hwnd)

        if !windowData.windowCreated { break }

        if wParam == win32.SIZE_MINIMIZED { break }

        clientRect: win32.RECT
        win32.GetClientRect(hwnd, &clientRect)

        windowSizeChangedHandler(windowData, clientRect.right - clientRect.left, clientRect.bottom - clientRect.top)

        calculateLines(windowData)
        updateCusrorData(windowData)
        validateTopLine(windowData)

        // NOTE: while resizing we only get resize message, so we can't redraw from main loop, so we do it explicitlly
        render(windowData.directXState, windowData)
    case win32.WM_KEYDOWN:
        handle_WM_KEYDOWN(lParam, wParam, getWindowData(hwnd))
    case win32.WM_CHAR:
        windowData := getWindowData(hwnd)

        if windowData.wasInputSymbolTyped && windowData.isInputMode {
            edit.input_rune(&windowData.inputState, rune(wParam))
            
            calculateLines(windowData)
            updateCusrorData(windowData)
            jumpToCursor(windowData, windowData.screenGlyphs.cursorLineIndex)
        }
    case win32.WM_MOUSEWHEEL:
        windowData := getWindowData(hwnd)

        yoffset := win32.GET_WHEEL_DELTA_WPARAM(wParam)

        // TODO: move it out!
        // if yoffset > 10 {
        //     windowData.screenGlyphs.lineIndex -= 1
        // } else if yoffset < -10 {
        //     windowData.screenGlyphs.lineIndex += 1
        // }

        windowData.scrollDelta = i32(yoffset)

        validateTopLine(windowData)
    case win32.WM_COMMAND:        
        windowData := getWindowData(hwnd)

		menuItemId := win32.LOWORD(u32(wParam))

        switch menuItemId {
        case IDM_FILE_OPEN:
            filePath, ok := showOpenFileDialog(windowData)
            if !ok { break }

            windowData.openedFilePath = filePath
            fileContent := os.read_entire_file_from_filename(filePath) or_else panic("Failed to read file")
            originalFileText := string(fileContent[:])
        
            testText, wasNewAllocation := strings.remove_all(originalFileText, "\r")

            if wasNewAllocation {
                delete(fileContent)
            }

            strings.builder_reset(&windowData.text)

            strings.write_string(&windowData.text, testText)
            
            edit.init(&windowData.inputState, context.allocator, context.allocator)
            edit.setup_once(&windowData.inputState, &windowData.text)
            windowData.inputState.selection = { 0, 0 }
            windowData.screenGlyphs.lineIndex = 0
        case IDM_FILE_SAVE_AS:
            ok := showSaveAsFileDialog(windowData)

            if !ok { break }
        case IDM_FILE_SAVE:
            saveToOpenedFile(windowData)
        }
    case win32.WM_DESTROY:
        win32.PostQuitMessage(0)
    }

    return win32.DefWindowProcA(hwnd, msg, wParam, lParam)
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

    if !windowData.isInputMode { return }
    
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
            char := windowData.text.buf[i]

            if char != ' ' && char != '\t' {
                break
            }
            whiteSpacesCount += 1
        }

        edit.perform_command(&windowData.inputState, edit.Command.New_Line)

        if whiteSpacesCount > 0 {
            edit.input_text(&windowData.inputState, string(windowData.text.buf[lineStart:][:whiteSpacesCount]))
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
        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Up)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Up)
        }
    case win32.VK_DOWN:
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
        jumpToCursor(windowData, windowData.screenGlyphs.cursorLineIndex)

        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Line_Start)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_Start)
        }
    case win32.VK_END:
        jumpToCursor(windowData, windowData.screenGlyphs.cursorLineIndex)

        if isShiftPressed() {
            edit.perform_command(&windowData.inputState, edit.Command.Select_Line_End)
        } else {
            edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_End)
        }
    case win32.VK_A:
        edit.perform_command(&windowData.inputState, edit.Command.Select_All)
    case win32.VK_C:
        if edit.has_selection(&windowData.inputState) {
            edit.perform_command(&windowData.inputState, edit.Command.Copy)
        }
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
        saveToOpenedFile(windowData)
    }

    switch wParam {
    case win32.VK_RETURN, win32.VK_TAB,
        win32.VK_LEFT, win32.VK_RIGHT, win32.VK_UP, win32.VK_DOWN,
        win32.VK_BACK, win32.VK_DELETE,
        win32.VK_V, win32.VK_X, win32.VK_Z:
            calculateLines(windowData)
            updateCusrorData(windowData)
            jumpToCursor(windowData, windowData.screenGlyphs.cursorLineIndex)
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

    viewMatrix := getOrthoraphicsMatrix(f32(width), f32(height), 0.1, windowData.maxZIndex + 1.0)

    updateGpuBuffer(&viewMatrix, directXState.constantBuffers[.PROJECTION], directXState)
}
