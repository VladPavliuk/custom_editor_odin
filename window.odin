package main

import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:text/edit"

import "vendor:glfw"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

import win32 "core:sys/windows"

WindowData :: struct {
    size: int2,

    directXState: ^DirectXState,

    linesTopOffset: i32,
    isInputMode: bool,
    testInputString: strings.Builder,
    inputState: edit.State,

    // cursorIndex: i32, // index in string
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
    testText := `Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
Donec consequat lorem eget arcu congue, commodo dignissim elit tincidunt. 
Quisque mattis nisl in orci rutrum feugiat. Proin sed est ipsum. Proin eget ultrices turpis. 
Aliquam in placerat elit, vitae accumsan dolor. 
Etiam 
    lobortis ex eu blandit cursus. In egestas leo magna, vel placerat eros
bibendum eu.

Aenean eu aliquet ex. Cras ultricies dolor in diam vulputate, sit amet placerat velit venenatis. Vestibulum tincidunt
dapibus tellus, sed rhoncus leo gravida ac. Ut dictum elit sit
amet odio fringilla posuere. Etiam at nulla a risus blandit sodales. 
Aliquam rutrum felis eros, sed placerat urna sodales at. Nulla eu orci sed dui scelerisque egestas. 
Fusce nec finibus erat. Morbi sagittis augue et risus tempus pulvinar. Cras vehicula eu nunc ac ultrices. 
Donec nulla erat, laoreet sed lacus ac, porttitor ultrices orci. Integer vulputate lorem ac imperdiet laoreet. 
Etiam vitae commodo odio, quis tempus libero. 
Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.

Nunc enim augue, maximus quis cursus sit amet, eleifend et nunc. Maecenas et tortor dictum nisi tincidunt rutrum. 
Curabitur vel dapibus libero, in finibus erat. Curabitur ut libero vitae dolor molestie aliquet. 
Ut consequat diam vitae odio porta cursus. Nunc hendrerit nisl nec risus tempus ornare. 
Vestibulum et finibus sapien. 
Vivamus ipsum est, efficitur lobortis vestibulum finibus, tempor ut est. Sed lacus velit, pretium eget lectus in, euismod convallis sapien. 
Donec sed rutrum purus. Nunc odio enim, rutrum mattis lorem eu, 
hendrerit varius enim. Sed fermentum volutpat nibh eu aliquam. 
Sed nibh urna, tempor eu dolor quis, convallis rhoncus metus. 
Duis fermentum accumsan scelerisque. 
Aenean mollis, tellus at luctus vehicula, mauris 
dolor mattis turpis, at ultricies dui dolor quis sapien.`
    strings.write_string(&windowData.testInputString, testText)
    edit.init(&windowData.inputState, context.allocator, context.allocator)
    edit.setup_once(&windowData.inputState, &windowData.testInputString)
    windowData.inputState.selection[0] = 0

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
            edit.perform_command(&windowData.inputState, edit.Command.Backspace)
        }

        if isKeyDown(glfw.KEY_DELETE, key, action) || isKeyRepeated(glfw.KEY_DELETE, key, action) {
            edit.perform_command(&windowData.inputState, edit.Command.Delete)
        }

        if isKeyDown(glfw.KEY_LEFT, key, action) || isKeyRepeated(glfw.KEY_LEFT, key, action) {
            edit.move_to(&windowData.inputState, edit.Translation.Left)
        }

        if isKeyDown(glfw.KEY_RIGHT, key, action) || isKeyRepeated(glfw.KEY_RIGHT, key, action) {
            edit.move_to(&windowData.inputState, edit.Translation.Right)
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

keychardCharInputHandler :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
    context = runtime.default_context()
    windowData := (^WindowData)(glfw.GetWindowUserPointer(window))

    if windowData.isInputMode {
        // edit.begin(&windowData.inputState, 1, &windowData.testInputString)
        edit.input_rune(&windowData.inputState, codepoint)
        // edit.end(&windowData.inputState)

        // strings.write_rune(&windowData.testInputString, codepoint)
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

    updateConstantBuffer(&viewMatrix, directXState.constantBuffers[.PROJECTION], directXState)
}