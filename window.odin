package main

import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:text/edit"
import "core:os"
import "core:bytes"

import "vendor:glfw"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

import win32 "core:sys/windows"

GlyphItem :: struct {
    char: rune,
    // runeIndex: i32,
    indexInString: i64, // char index in source string
    // lineIndex: i16, // line index on screen
    x: f32,
    y: f32,
    width: f32,
    height: f32,
}

ScreenGlyphs :: struct {
    // cursorIndex: i32,
    lineIndex: i32,
    cursorLineIndex: i32,
    lineHeight: i32,
    layout: [dynamic]GlyphItem,
    lines: [dynamic]int2, // { start line char index, end char line index }
}

WindowData :: struct {
    size: int2,
    mousePosition: float2,
    isLeftMouseButtonDown: bool,
    directXState: ^DirectXState,

    font: FontData,

    linesTopOffset: i32,
    isInputMode: bool,
    testInputString: strings.Builder,
    inputState: edit.State,
    screenGlyphs: ScreenGlyphs,

    cursorScreenPosition: float2,
}

createWindow :: proc(size: int2) -> (glfw.WindowHandle, win32.HWND, ^WindowData) {
    assert(i32(glfw.Init()) != 0)

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    
    // window := glfw.CreateWindow(1920, 1080, "test", glfw.GetPrimaryMonitor(), nil)
    window := glfw.CreateWindow(size.x, size.y, "test", nil, nil)

    glfw.MakeContextCurrent(window)
    
    hwnd := glfw.GetWin32Window(window)

    windowData := new(WindowData)
    windowData.size = size
    windowData.testInputString = strings.builder_make()

    windowData.screenGlyphs.lineIndex = 0
    fileContent := os.read_entire_file_from_filename("../test_text_file.txt") or_else panic("Failed to read file")
    originalFileText := string(fileContent[:])
   
    //TODO: add handling Window's \r\n staff
    testText, wasNewAllocation := strings.remove_all(originalFileText, "\r")

    if wasNewAllocation {
        delete(fileContent)
    }

    // testText := "ів\na\nф"
    strings.write_string(&windowData.testInputString, testText)

    edit.init(&windowData.inputState, context.allocator, context.allocator)
    edit.setup_once(&windowData.inputState, &windowData.testInputString)
    windowData.inputState.selection = { 0, 0 }

    windowData.isInputMode = true

    glfw.SetWindowUserPointer(window, windowData)

    return window, hwnd, windowData
}

isKeyDown :: proc "c" (keyToCheck: i32, key: i32, action: i32) -> bool {
    return action == glfw.PRESS && keyToCheck == key
}

isKeyRepeated :: proc(keyToCheck: i32, key: i32, action: i32) -> bool {
    return action == glfw.REPEAT && keyToCheck == key
}

isKeyReleased :: proc(keyToCheck: i32, key: i32, action: i32) -> bool {
    return action == glfw.RELEASE && keyToCheck == key
}

keyboardHandler :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = runtime.default_context()
    
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    if windowData.isInputMode {
        if isKeyDown(glfw.KEY_ENTER, key, action) || isKeyRepeated(glfw.KEY_ENTER, key, action) {
            edit.perform_command(&windowData.inputState, edit.Command.New_Line)
        }

        if isKeyDown(glfw.KEY_BACKSPACE, key, action) || isKeyRepeated(glfw.KEY_BACKSPACE, key, action) {
            if (mods & glfw.MOD_CONTROL) == glfw.MOD_CONTROL {
                edit.perform_command(&windowData.inputState, edit.Command.Delete_Word_Left)
            } else {
                edit.perform_command(&windowData.inputState, edit.Command.Backspace)
            }
        }

        if isKeyDown(glfw.KEY_DELETE, key, action) || isKeyRepeated(glfw.KEY_DELETE, key, action) {
            if (mods & glfw.MOD_CONTROL) == glfw.MOD_CONTROL {
                edit.perform_command(&windowData.inputState, edit.Command.Delete_Word_Right)
            } else {
                edit.perform_command(&windowData.inputState, edit.Command.Delete)
            }
        }

        if isKeyDown(glfw.KEY_LEFT, key, action) || isKeyRepeated(glfw.KEY_LEFT, key, action) {
            if (mods & glfw.MOD_CONTROL) == glfw.MOD_CONTROL {
                edit.move_to(&windowData.inputState, edit.Translation.Word_Left)
            } else {
                edit.move_to(&windowData.inputState, edit.Translation.Left)
            }
        }

        if isKeyDown(glfw.KEY_RIGHT, key, action) || isKeyRepeated(glfw.KEY_RIGHT, key, action) {
            if (mods & glfw.MOD_CONTROL) == glfw.MOD_CONTROL {
                edit.move_to(&windowData.inputState, edit.Translation.Word_Right)
            } else {
                edit.move_to(&windowData.inputState, edit.Translation.Right)
            }
        }

        if isKeyDown(glfw.KEY_UP, key, action) || isKeyRepeated(glfw.KEY_UP, key, action) {
            if windowData.screenGlyphs.cursorLineIndex <= windowData.screenGlyphs.lineIndex {
                windowData.screenGlyphs.lineIndex -= 1
                windowData.screenGlyphs.lineIndex = max(0, windowData.screenGlyphs.lineIndex)
            }

            edit.move_to(&windowData.inputState, edit.Translation.Up)
        }

        if isKeyDown(glfw.KEY_DOWN, key, action) || isKeyRepeated(glfw.KEY_DOWN, key, action) {
            maxLinesOnScreen := i32(f32(windowData.size.y) / windowData.font.lineHeight)

            if windowData.screenGlyphs.cursorLineIndex >= windowData.screenGlyphs.lineIndex + maxLinesOnScreen - 1 {
                windowData.screenGlyphs.lineIndex += 1
                // windowData.screenGlyphs.lineIndex = max(windowData.screenGlyphs.lineIndex + maxLinesOnScreen, windowData.screenGlyphs.lineIndex)
            }

            edit.move_to(&windowData.inputState, edit.Translation.Down)
        }

        // test := glfw.GetKeyLock(window, key);
        // glfw.MOD_NUM_LOCK

        // if isKeyDown(glfw.KEY_HOME, key, action) || isKeyRepeated(glfw.KEY_HOME, key, action) {
        //     edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_Start)
        // }

        // TODO: for now it's TAB button, since if home button is on numlock keyboard it's not that easy to catch it 
        if isKeyDown(glfw.KEY_TAB, key, action) || isKeyRepeated(glfw.KEY_TAB, key, action) {
            edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_Start)
        }

        if isKeyDown(glfw.KEY_END, key, action) || isKeyRepeated(glfw.KEY_END, key, action) {
            edit.move_to(&windowData.inputState, edit.Translation.Soft_Line_End)
        }
    }

    if isKeyReleased(glfw.KEY_ESCAPE, key, action) {
        glfw.SetWindowShouldClose(window, true)
    }

    if isKeyDown(glfw.KEY_A, key, action) {
        //windowData.a += 0.1
    }

    if isKeyReleased(glfw.KEY_A, key, action) {
        // windowData.a -= .1
    }
}

mousePositionHandler :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    windowData.mousePosition.x = f32(xpos)
    windowData.mousePosition.y = f32(ypos)
    
    // make sure that mouse position is not out of window box
    windowData.mousePosition.x = max(0, windowData.mousePosition.x)
    windowData.mousePosition.y = max(0, windowData.mousePosition.y)
    
    windowData.mousePosition.x = min(f32(windowData.size.x), windowData.mousePosition.x)
    windowData.mousePosition.y = min(f32(windowData.size.y), windowData.mousePosition.y)
}

mouseClickHandler :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    windowData.isLeftMouseButtonDown = button == glfw.MOUSE_BUTTON_LEFT && action == glfw.PRESS
}

keychardCharInputHandler :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    if windowData.isInputMode {
        edit.input_rune(&windowData.inputState, codepoint)
    }
}

windowSizeChangedHandler :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    windowData.size = { width, height }
    directXState := windowData.directXState

    nullViews := []^d3d11.IRenderTargetView{ nil }
    directXState.ctx->OMSetRenderTargets(1, raw_data(nullViews), nil)
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