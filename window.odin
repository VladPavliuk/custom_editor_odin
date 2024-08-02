package main

import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:text/edit"

import "vendor:glfw"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

import win32 "core:sys/windows"

GlyphItem :: struct {
    char: rune,
    index: i64,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    // rect: Rect, // on screen rect
    // lineIndex: i16,
}

WindowData :: struct {
    size: int2,

    directXState: ^DirectXState,

    linesTopOffset: i32,
    isInputMode: bool,
    testInputString: strings.Builder,
    inputState: edit.State,
    glyphsLayout: [dynamic]GlyphItem,

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
    // around 5k symbols
    testText := `Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Donec consequat lorem eget arcu congue, commodo dignissim elit tincidunt.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Quisque mattis nisl in orci rutrum feugiat. Proin sed est ipsum. Proin eget ultrices turpis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aliquam in placerat elit, vitae accumsan dolor.  Aenean eu aliquet ex. Cras ultricies dolor in diam vulputate, sit Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Etiam Aenean eu aliquet ex. Cras ultricies dolor in diam vulputate, sit amet placerat velit venenatis. Vestibulum tincidunt Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
lobortis ex eu blandit cursus. In egestas leo magna, vel placerat eros Aenean eu aliquet ex. Cras ultricies do Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
bibendum eu. Aenean eu aliquet ex. Cras ultricies dolor in diam vulputate, sit amet placerat velit venenatis. Vestibulum tincidunt Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean eu aliquet ex. Cras ultricies dolor in diam vulputate, sit amet placerat velit venenatis. Vestibulum tincidunt Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean eu aliquet ex. Cras ultricies dolor in diam vulputate, sit amet placerat velit venenatis. Vestibulum tincidunt Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
dapibus tellus, sed rhoncus leo gravida ac. Ut dictum elit sit Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
amet odio fringilla posuere. Etiam at nulla a risus blandit sodales.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aliquam rutrum felis eros, sed placerat urna sodales at. Nulla eu orci sed dui scelerisque egestas.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Fusce nec finibus erat. Morbi sagittis augue et risus tempus pulvinar. Cras vehicula eu nunc ac ultrices. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Donec nulla erat, laoreet sed lacus ac, porttitor ultrices orci. Integer vulputate lorem ac imperdiet laoreet.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Etiam vitae commodo odio, quis tempus libero. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Nunc enim augue, maximus quis cursus sit amet, eleifend et nunc. Maecenas et tortor dictum nisi tincidunt rutrum. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Curabitur vel dapibus libero, in finibus erat. Curabitur ut libero vitae dolor molestie aliquet.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Ut consequat diam vitae odio porta cursus. Nunc hendrerit nisl nec risus tempus ornare. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Vestibulum et finibus sapien. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Vivamus ipsum est, efficitur lobortis vestibulum finibus, tempor ut est. Sed lacus velit, pretium eget lectus in, euismod convallis sapien.  
Donec sed rutrum purus. Nunc odio enim, rutrum mattis lorem eu, Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
hendrerit varius enim. Sed fermentum volutpat nibh eu aliquam.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Sed nibh urna, tempor eu dolor quis, convallis rhoncus metus.  Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Duis fermentum accumsan scelerisque. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean mollis, tellus at luctus vehicula, mauris Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean mollis, tellus at luctus vehicula, mauris Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean mollis, tellus at luctus vehicula, mauris Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean mollis, tellus at luctus vehicula, mauris Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean mollis, tellus at luctus vehicula, mauris Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
Aenean mollis, tellus at luctus vehicula, mauris Donec nisl est, aliquet id accumsan efficitur, luctus eu felis. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.
dolor mattis turpis, at ultricies dui dolor quis sapien. Donec nisl est, aliquet id accumsan efficitur, luctus eu felis.` 
    strings.write_string(&windowData.testInputString, testText)
    edit.init(&windowData.inputState, context.allocator, context.allocator)
    edit.setup_once(&windowData.inputState, &windowData.testInputString)
    windowData.inputState.selection[0] = 0

    test := len(testText)
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

    updateGpuBuffer(&viewMatrix, directXState.constantBuffers[.PROJECTION], directXState)
}