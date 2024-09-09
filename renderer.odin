package main

import "core:strings"

import "base:intrinsics"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "core:unicode/utf8"
import "core:fmt"

import "core:time"
import "core:math"
import "core:strconv"

// TODO: make all them configurable
RED_COLOR := float4{ 1.0, 0.0, 0.0, 1.0 }
GREEN_COLOR := float4{ 0.0, 1.0, 0.0, 1.0 }
BLUE_COLOR := float4{ 0.0, 0.0, 1.0, 1.0 }
YELLOW_COLOR := float4{ 1.0, 1.0, 0.0, 1.0 }
WHITE_COLOR := float4{ 1.0, 1.0, 1.0, 1.0 }
BLACK_COLOR := float4{ 0.0, 0.0, 0.0, 1.0 }
LIGHT_GRAY_COLOR := float4{ 0.5, 0.5, 0.5, 1.0 }
GRAY_COLOR := float4{ 0.3, 0.3, 0.3, 1.0 }
DARKER_GRAY_COLOR := float4{ 0.2, 0.2, 0.2, 1.0 }
DARK_GRAY_COLOR := float4{ 0.1, 0.1, 0.1, 1.0 }

EDITOR_BG_COLOR := float4{ 0.0, 0.25, 0.5, 1.0 }
CURSOR_COLOR := float4{ 0.0, 0.0, 0.0, 1.0 }
CURSOR_LINE_BG_COLOR := float4{ 1.0, 1.0, 1.0, 0.1 }
LINE_NUMBERS_BG_COLOR := float4{ 0.0, 0.0, 0.0, 0.3 }
TEXT_SELECTION_BG_COLOR := float4{ 1.0, 0.5, 1.0, 0.3 }

THEME_COLOR_1 := float4{ 251 / 255.0, 133 / 255.0, 0 / 255.0, 1.0 }
THEME_COLOR_2 := float4{ 251 / 255.0, 183 / 255.0, 0 / 255.0, 1.0 }
THEME_COLOR_3 := float4{ 2 / 255.0, 48 / 255.0, 71 / 255.0, 1.0 }
THEME_COLOR_4 := float4{ 33 / 255.0, 158 / 255.0, 188 / 255.0, 1.0 }
THEME_COLOR_5 := float4{ 142 / 255.0, 202 / 255.0, 230 / 255.0, 1.0 }

render :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    ctx := directXState.ctx

    bgColor: [4]f32 = EDITOR_BG_COLOR.xyzw
    ctx->ClearRenderTargetView(directXState.backBufferView, &bgColor)
    ctx->ClearDepthStencilView(directXState.depthBufferView, { .DEPTH, .STENCIL }, 1.0, 0)
    
    ctx->OMSetRenderTargets(1, &directXState.backBufferView, directXState.depthBufferView)
    ctx->OMSetDepthStencilState(directXState.depthStencilState, 0)
    ctx->RSSetState(directXState.rasterizerState)
    ctx->OMSetBlendState(directXState.blendState, nil, 0xFFFFFFFF)

	ctx->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    ctx->IASetInputLayout(directXState.inputLayouts[.POSITION_AND_TEXCOORD])

    offsets := [?]u32{ 0 }
    strideSize := [?]u32{directXState.vertexBuffers[.QUAD].strideSize}
	ctx->IASetVertexBuffers(0, 1, &directXState.vertexBuffers[.QUAD].gpuBuffer, raw_data(strideSize[:]), raw_data(offsets[:]))
	ctx->IASetIndexBuffer(directXState.indexBuffers[.QUAD].gpuBuffer, dxgi.FORMAT.R32_UINT, 0)

    //> ui testing
    uiStaff(windowData)
    //<

    //renderRectBorder(directXState, { -200, -200 }, {50,100}, 1.0, 1.0, GRAY_COLOR)
    @(static)
    timeElapsedTotal: f64 = 0.0
    
    @(static)
    timeElapsedCount: i32 = 0
 
    timer: time.Stopwatch
    time.stopwatch_start(&timer)    

    glyphsCount, selectionsCount := fillTextBuffer(directXState, windowData)
    time.stopwatch_stop(&timer)

    if windowData.isInputMode {
        calculateLines(windowData)
        findCursorPosition(windowData)
        updateCusrorData(windowData)
    }
    
    elapsed := time.duration_microseconds(timer._accumulation)
    timeElapsedTotal += elapsed
    timeElapsedCount += 1
    // fmt.printfln("Duration avg: %f", timeElapsedTotal / f64(timeElapsedCount))
    
    renderText(directXState, windowData, glyphsCount, selectionsCount)
    renderLineNumbers(directXState, windowData)

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}

testingButtons :: proc(windowData: ^WindowData) {
    if action := renderButton(windowData, UiButton{
        text = "Test 1",
        position = { 0, 0 },
        size = { 100, 30 },
        // color = WHITE_COLOR,
        bgColor = THEME_COLOR_3,
        // hoverBgColor = BLACK_COLOR,
    }); action != nil {
        fmt.print("Test 1 - ")

        if .SUBMIT in action { fmt.print("SUBMIT ") }
        if .HOT in action { fmt.print("HOT ") }
        if .ACTIVE in action { fmt.print("ACTIVE ") }
        if .GOT_ACTIVE in action { fmt.print("GOT_ACTIVE ") }
        if .LOST_ACTIVE in action { fmt.print("LOST_ACTIVE ") }
        if .MOUSE_ENTER in action { fmt.print("MOUSE_ENTER ") }
        if .MOUSE_LEAVE in action { fmt.print("MOUSE_LEAVE ") }

        fmt.print('\n')
    }

    if action := renderButton(windowData, UiButton{
        text = "Test 2",
        position = { 40, 10 },
        size = { 100, 30 },
        // color = WHITE_COLOR,
        bgColor = THEME_COLOR_1,
        // hoverBgColor = BLACK_COLOR,
    }); action != nil {
        fmt.print("Test 2 - ")

        if .SUBMIT in action { fmt.print("SUBMIT ") }
        if .HOT in action { fmt.print("HOT ") }
        if .ACTIVE in action { fmt.print("ACTIVE ") }
        if .GOT_ACTIVE in action { fmt.print("GOT_ACTIVE ") }
        if .LOST_ACTIVE in action { fmt.print("LOST_ACTIVE ") }
        if .MOUSE_ENTER in action { fmt.print("MOUSE_ENTER ") }
        if .MOUSE_LEAVE in action { fmt.print("MOUSE_LEAVE ") }

        fmt.print('\n')
    }
}

uiStaff :: proc(windowData: ^WindowData) {
    beginUi(windowData)

    testingButtons(windowData)

    renderVerticalScrollBar(windowData)

    @(static)
    showPanel := false
    
    if .SUBMIT in renderButton(windowData, UiButton{
        text = "Show/Hide panel",
        position = { 39, -100 },
        size = { 150, 30 },
        // color = WHITE_COLOR,
        bgColor = THEME_COLOR_4,
        // hoverBgColor = BLACK_COLOR,
    }) { showPanel = !showPanel }
    
    if showPanel {
        @(static)
        panelPosition: int2 = { -250, -100 } 

        @(static)
        panelSize: int2 = { 200, 300 }

        beginPanel(windowData, UiPanel{
            title = "PANEL 1",
            position = &panelPosition,
            size = &panelSize,
            bgColor = THEME_COLOR_1,
            // hoverBgColor = THEME_COLOR_5,
        })

        @(static)
        checked := false
        renderCheckbox(windowData, UiCheckbox{
            text = "test checkbox",
            checked = &checked,
            position = { 0, 0 },
            color = WHITE_COLOR,
            bgColor = GREEN_COLOR,
            hoverBgColor = BLACK_COLOR,
        })    
        
        endPanel(windowData)
    }


    // @(static)
    // offset: i32 = 0
    // renderVerticalScroll(windowData, UiScroll{
    //     bgRect = Rect{
    //         top = 150, bottom = -150,
    //         left = 50, right = 100,
    //     },
    //     offset = &offset,
    //     height = 30,
    //     color = THEME_COLOR_3,
    //     hoverColor = THEME_COLOR_2,
    //     bgColor = THEME_COLOR_1,
    // })

    endUi(windowData)

    windowData.isInputMode = windowData.activeUiId == {}
}

renderRect :: proc{renderRectVec_Float, renderRectVec_Int, renderRect_Int}

renderRect_Int :: proc(directXState: ^DirectXState, rect: Rect, zValue: f32, color: float4) {
    renderRectVec_Float(directXState, { f32(rect.left), f32(rect.bottom) }, 
        { f32(rect.right - rect.left), f32(rect.top - rect.bottom) }, zValue, color)
}

renderRectVec_Int :: proc(directXState: ^DirectXState, position, size: int2, zValue: f32, color: float4) {
    renderRectVec_Float(directXState, { f32(position.x), f32(position.y) }, { f32(size.x), f32(size.y) }, zValue, color)
}

renderRectVec_Float :: proc(directXState: ^DirectXState, position, size: float2, zValue: f32, color: float4) {
    color := color
    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.BASIC], nil, 0)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
    ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    modelMatrix := getTransformationMatrix(
        { position.x, position.y, zValue }, 
        { 0.0, 0.0, 0.0 }, { size.x, size.y, 1.0 })

    updateGpuBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION], directXState)
    updateGpuBuffer(&color, directXState.constantBuffers[.COLOR], directXState)

    directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)
}

renderRectBorder :: proc{renderRectBorderVec_Float, renderRectBorderVec_Int, renderRectBorder_Int}

renderRectBorder_Int :: proc(directXState: ^DirectXState, rect: Rect, thickness, zValue: f32, color: float4) {
    renderRectBorderVec_Float(directXState, { f32(rect.left), f32(rect.bottom) }, 
        { f32(rect.right - rect.left), f32(rect.top - rect.bottom) }, thickness, zValue, color)
}

renderRectBorderVec_Int :: proc(directXState: ^DirectXState, position, size: int2, thickness, zValue: f32, color: float4) {
    renderRectBorderVec_Float(directXState, { f32(position.x), f32(position.y) }, { f32(size.x), f32(size.y) }, thickness, zValue, color)
}

renderRectBorderVec_Float :: proc(directXState: ^DirectXState, position, size: float2, thickness, zValue: f32, color: float4) {
    renderRect(directXState, float2{ position.x, position.y + size.y - thickness }, float2{ size.x, thickness }, zValue, color) // top border
    renderRect(directXState, position, float2{ size.x, thickness }, zValue, color) // bottom border
    renderRect(directXState, position, float2{ thickness, size.y }, zValue, color) // left border
    renderRect(directXState, float2{ position.x + size.x - thickness, position.y }, float2{ thickness, size.y }, zValue, color) // right border
}

renderLine :: proc(directXState: ^DirectXState, windowData: ^WindowData, text: string, position: int2, color: float4, zIndex: f32) {
    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)
    
    leftOffset := f32(position.x)
    topOffset := f32(position.y) - windowData.font.descent

    for char, index in text {
        fontChar := windowData.font.chars[char]

        glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
        glyphPosition: int2 = { i32(leftOffset) + fontChar.offset.x, i32(topOffset) - glyphSize.y - fontChar.offset.y }

        modelMatrix := getTransformationMatrix(
            { f32(glyphPosition.x), f32(glyphPosition.y), zIndex }, 
            { 0.0, 0.0, 0.0 }, 
            { f32(glyphSize.x), f32(glyphSize.y), 1.0 },
        )
        
        fontsList[index] = FontGlyphGpu{
            sourceRect = fontChar.rect,
            targetTransformation = intrinsics.transpose(modelMatrix), 
        }
        leftOffset += fontChar.xAdvance
    }

    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    color := color // whithout it we won't be able to pass color as a pointer
    updateGpuBuffer(&color, directXState.constantBuffers[.COLOR], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(len(text)), 0, 0, 0)
}

renderCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData, position: int2) {
    renderRect(directXState, float2{ f32(position.x), f32(position.y) }, float2{ 3.0, windowData.font.lineHeight }, 
        windowData.maxZIndex - 3.0, CURSOR_COLOR)
}

fillTextBuffer :: proc(directXState: ^DirectXState, windowData: ^WindowData) -> (i32, i32) {
    stringToRender := strings.to_string(windowData.text)

    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)

    rectsListBuffer := directXState.structuredBuffers[.RECTS_LIST]
    rectsList := memoryAsSlice(mat4, rectsListBuffer.cpuBuffer, rectsListBuffer.length)

    topLine := windowData.screenGlyphs.lineIndex
    bottomLine := i32(len(windowData.screenGlyphs.lines))

    editorSize := getEditorSize(windowData)

    topOffset := math.round(f32(windowData.size.y) / 2.0 - windowData.font.lineHeight) - f32(windowData.editorPadding.top)

    glyphsCount := 0
    selectionsCount := 0
    hasSelection := windowData.inputState.selection[0] != windowData.inputState.selection[1]
    selectionRange: int2 = {
        i32(min(windowData.inputState.selection[0], windowData.inputState.selection[1])),
        i32(max(windowData.inputState.selection[0], windowData.inputState.selection[1])),
    }
    
    for lineIndex in topLine..<bottomLine {
        if topOffset < -f32(editorSize.y) / 2 {
            break
        }
        line := windowData.screenGlyphs.lines[lineIndex]

        leftOffset: f32 = -f32(windowData.size.x) / 2.0 + f32(windowData.editorPadding.left)
        
        if lineIndex == windowData.screenGlyphs.cursorLineIndex {
            renderRect(directXState, float2{ leftOffset, topOffset }, float2{ f32(editorSize.x), windowData.font.lineHeight }, windowData.maxZIndex, CURSOR_LINE_BG_COLOR)
        }

        byteIndex := line.x
        for byteIndex <= line.y {
            // TODO: add RUNE_ERROR handling
            char, charSize := utf8.decode_rune(stringToRender[byteIndex:])

            defer byteIndex += i32(charSize)

            fontChar := windowData.font.chars[char]

            glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
            glyphPosition: int2 = { i32(leftOffset) + fontChar.offset.x, i32(topOffset) - glyphSize.y - fontChar.offset.y }

            if int(byteIndex) == windowData.inputState.selection[0] {
                renderCursor(directXState, windowData, glyphPosition)
            }

            // NOTE: last symbol in string is EOF which has 0 length
            // TODO: optimize it
            if charSize == 0 { break }

            if hasSelection && byteIndex >= selectionRange.x && byteIndex < selectionRange.y  {
                rectsList[selectionsCount] = intrinsics.transpose(getTransformationMatrix(
                    { leftOffset, topOffset, windowData.maxZIndex - 1.0 }, 
                    { 0.0, 0.0, 0.0 }, 
                    { fontChar.xAdvance, windowData.font.lineHeight, 1.0 },
                ))
                selectionsCount += 1
            }

            modelMatrix := getTransformationMatrix(
                { f32(glyphPosition.x), f32(glyphPosition.y), windowData.maxZIndex - 2.0 }, 
                { 0.0, 0.0, 0.0 }, 
                { f32(glyphSize.x), f32(glyphSize.y), 1.0 },
            )
            
            fontsList[glyphsCount] = FontGlyphGpu{
                sourceRect = fontChar.rect,
                targetTransformation = intrinsics.transpose(modelMatrix), 
            }
            glyphsCount += 1
        
            leftOffset += fontChar.xAdvance
        }
        
        topOffset -= windowData.font.lineHeight
    }

    return i32(glyphsCount), i32(selectionsCount)
}

renderLineNumbers :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    maxLinesOnScreen := i32(f32(getEditorSize(windowData).y) / windowData.font.lineHeight)

    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)
    
    // draw background
    renderRect(directXState, float2{ -f32(windowData.size.x) / 2.0, -f32(windowData.size.y) / 2.0 }, 
        float2{ f32(windowData.editorPadding.left), f32(windowData.size.y) }, windowData.maxZIndex, LINE_NUMBERS_BG_COLOR)

    topOffset := math.round(f32(windowData.size.y) / 2.0 - windowData.font.lineHeight) - f32(windowData.editorPadding.top)
    
    lineNumberStrBuffer: [255]byte
    glyphsCount := 0
    
    firstNumber := windowData.screenGlyphs.lineIndex + 1
    lastNumber := min(i32(len(windowData.screenGlyphs.lines)), windowData.screenGlyphs.lineIndex + maxLinesOnScreen)

    for lineIndex in firstNumber..=lastNumber {
        lineNumberStr := strconv.itoa(lineNumberStrBuffer[:], int(lineIndex))

        leftOffset := -f32(windowData.size.x) / 2.0

        for digit in lineNumberStr {
            fontChar := windowData.font.chars[digit]

            glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
            glyphPosition: int2 = { i32(leftOffset) + fontChar.offset.x, i32(topOffset) - glyphSize.y - fontChar.offset.y }

            modelMatrix := getTransformationMatrix(
                { f32(glyphPosition.x), f32(glyphPosition.y), windowData.maxZIndex - 1.0 }, 
                { 0.0, 0.0, 0.0 }, 
                { f32(glyphSize.x), f32(glyphSize.y), 1.0 },
            )
            
            fontsList[glyphsCount] = FontGlyphGpu{
                sourceRect = fontChar.rect,
                targetTransformation = intrinsics.transpose(modelMatrix), 
            }
            glyphsCount += 1
            leftOffset += fontChar.xAdvance
        }

        topOffset -= windowData.font.lineHeight
    }

    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    updateGpuBuffer(&WHITE_COLOR, directXState.constantBuffers[.COLOR], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(glyphsCount), 0, 0, 0)
}

// BENCHMARKS:
// +-20000 microseconds with -speed build option without instancing
// +-750 microseconds with -speed build option with instancing
renderText :: proc(directXState: ^DirectXState, windowData: ^WindowData, glyphsCount: i32, selectionsCount: i32) {
    ctx := directXState.ctx

    //> draw selection
    rectsListBuffer := directXState.structuredBuffers[.RECTS_LIST]
    rectsList := memoryAsSlice(mat4, rectsListBuffer.cpuBuffer, rectsListBuffer.length)

    ctx->VSSetShader(directXState.vertexShaders[.MULTIPLE_RECTS], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.RECTS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(rectsList, directXState.structuredBuffers[.RECTS_LIST], directXState)
    updateGpuBuffer(&TEXT_SELECTION_BG_COLOR, directXState.constantBuffers[.COLOR], directXState)

    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(selectionsCount), 0, 0, 0)
    //<
    
    //> draw text
    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)
    
    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(&WHITE_COLOR, directXState.constantBuffers[.COLOR], directXState)
    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(glyphsCount), 0, 0, 0)
    //<
}