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
EDITOR_BG_COLOR := [?]f32{ 0.0, 0.25, 0.5, 1.0 }
CURSOR_COLOR := [?]f32{ 0.0, 0.0, 0.0, 1.0 }
CURSOR_LINE_BG_COLOR := [?]f32{ 1.0, 1.0, 1.0, 0.1 }
LINE_NUMBERS_BG_COLOR := [?]f32{ 0.0, 0.0, 0.0, 0.3 }
TEXT_SELECTION_BG_COLOR := [?]f32{ 1.0, 0.5, 1.0, 0.3 }

render :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    ctx := directXState.ctx

    ctx->ClearRenderTargetView(directXState.backBufferView, &EDITOR_BG_COLOR)
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
    
    @(static)
    timeElapsedTotal: f64 = 0.0
    
    @(static)
    timeElapsedCount: i32 = 0
 
    timer: time.Stopwatch
    time.stopwatch_start(&timer)    

    calculateLines(windowData)

    findCursorPosition(windowData)
    updateCusrorData(windowData)
    glyphsCount, selectionsCount := fillTextBuffer(directXState, windowData)
    time.stopwatch_stop(&timer)

    elapsed := time.duration_microseconds(timer._accumulation)
    timeElapsedTotal += elapsed
    timeElapsedCount += 1
    fmt.printfln("Duration avg: %f", timeElapsedTotal / f64(timeElapsedCount))
    
    renderText(directXState, windowData, glyphsCount, selectionsCount)

    renderLineNumbers(directXState, windowData)

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}

renderRect :: proc(directXState: ^DirectXState, position, size: float2, zValue: f32, color: float4) {
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

renderCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData, position: int2) {
    renderRect(directXState, { f32(position.x), f32(position.y) }, { 3.0, windowData.font.lineHeight }, -1.0, float4(CURSOR_COLOR))
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
            renderRect(directXState, { leftOffset, topOffset }, { f32(editorSize.x), windowData.font.lineHeight }, 2.0, float4(CURSOR_LINE_BG_COLOR))
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
                    { leftOffset, topOffset, 1.0 }, 
                    { 0.0, 0.0, 0.0 }, 
                    { fontChar.xAdvance, windowData.font.lineHeight, 1.0 },
                ))
                selectionsCount += 1
            }

            modelMatrix := getTransformationMatrix(
                { f32(glyphPosition.x), f32(glyphPosition.y), 0.0 }, 
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
    renderRect(directXState, { -f32(windowData.size.x) / 2.0, -f32(windowData.size.y) / 2.0 }, 
        { f32(windowData.editorPadding.left), f32(windowData.size.y) }, 1.0, float4(LINE_NUMBERS_BG_COLOR))

    topOffset := math.round(f32(windowData.size.y) / 2.0 - windowData.font.lineHeight) - f32(windowData.editorPadding.top)
    
    lineNumberStrBuffer: [255]byte
    glyphsCount := 0
    
    firstNumber := windowData.screenGlyphs.lineIndex
    lastNumber := min(i32(len(windowData.screenGlyphs.lines)), windowData.screenGlyphs.lineIndex + maxLinesOnScreen)

    for lineIndex in firstNumber..<lastNumber {
        lineNumberStr := strconv.itoa(lineNumberStrBuffer[:], int(lineIndex))

        leftOffset := -f32(windowData.size.x) / 2.0

        for digit in lineNumberStr {
            fontChar := windowData.font.chars[digit]

            glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
            glyphPosition: int2 = { i32(leftOffset) + fontChar.offset.x, i32(topOffset) - glyphSize.y - fontChar.offset.y }

            modelMatrix := getTransformationMatrix(
                { f32(glyphPosition.x), f32(glyphPosition.y), 0.0 }, 
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

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
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

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(glyphsCount), 0, 0, 0)
    //<
}