package main

import "core:strings"

import "base:intrinsics"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "core:unicode/utf8"

import "core:time"
import "core:fmt"

render :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    ctx := directXState.ctx

    ctx->ClearRenderTargetView(directXState.backBufferView, &[?]f32{0.0, 0.5, 1.0, 1.0})
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
    //calculateLayout(windowData)

    findCursorPosition(windowData)
    updateCusrorData(windowData)
    glyphsCount := fillTextBuffer(directXState, windowData)
    
    time.stopwatch_stop(&timer)
    elapsed := time.duration_microseconds(timer._accumulation)
    timeElapsedTotal += elapsed
    timeElapsedCount += 1
    fmt.printfln("Duration avg: %f", timeElapsedTotal / f64(timeElapsedCount))
    
    renderText(directXState, windowData, glyphsCount)
    // renderCursor(directXState, windowData)

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}

renderCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData, position: float2) {
    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.BASIC], nil, 0)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
    ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    modelMatrix := getTransformationMatrix(
        { position.x, position.y, 0.0 }, 
        { 0.0, 0.0, 0.0 }, { 3.0, windowData.font.lineHeight, 1.0 })

    updateGpuBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION], directXState)

    directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)
}

fillTextBuffer :: proc(directXState: ^DirectXState, windowData: ^WindowData) -> i32 {
    stringToRender := strings.to_string(windowData.testInputString)

    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)

    topLine := windowData.screenGlyphs.lineIndex
    bottomLine := i32(len(windowData.screenGlyphs.lines))

    topOffset := f32(windowData.size.y) / 2.0 - windowData.font.lineHeight

    glyphsCount := 0
    hasSelection := windowData.inputState.selection[0] != windowData.inputState.selection[1]
    selectionRange: int2 = {
        i32(min(windowData.inputState.selection[0], windowData.inputState.selection[1])),
        i32(max(windowData.inputState.selection[0], windowData.inputState.selection[1])),
     }
    for lineIndex in topLine..<bottomLine {
        if topOffset < -f32(windowData.size.y) / 2 {
            break
        }
        line := windowData.screenGlyphs.lines[lineIndex]

        leftOffset: f32 = -f32(windowData.size.x) / 2.0
        for byteIndex in line.x..=line.y {
            // defer glyphsCount += 1
            // TODO: add RUNE_ERROR hndling
            char, _ := utf8.decode_rune(stringToRender[byteIndex:])

            fontChar := windowData.font.chars[char]

            glyphSize: float2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
            glyphPosition: float2 = { leftOffset + fontChar.offset.x, topOffset - glyphSize.y - fontChar.offset.y }

            if int(byteIndex) == windowData.inputState.selection[0] {
                renderCursor(directXState, windowData, glyphPosition)
            }

            if hasSelection && byteIndex >= selectionRange.x && byteIndex < selectionRange.y  {
                // panic("asd")
            } else {
                modelMatrix := getTransformationMatrix(
                    { glyphPosition.x, glyphPosition.y, 0.0 }, 
                    { 0.0, 0.0, 0.0 }, 
                    { glyphSize.x, glyphSize.y, 1.0 },
                )
                
                fontsList[glyphsCount] = FontGlyphGpu{
                    sourceRect = fontChar.rect,
                    targetTransformation = intrinsics.transpose(modelMatrix), 
                }
                glyphsCount += 1
            }
            leftOffset += fontChar.xAdvance
        }
        
        topOffset -= windowData.font.lineHeight
    }

    return i32(glyphsCount)
}

// BENCHMARKS:
// +-20000 microseconds with -speed build option without instancing
// +-750 microseconds with -speed build option with instancing
renderText :: proc(directXState: ^DirectXState, windowData: ^WindowData, glyphsCount: i32) {
    ctx := directXState.ctx
    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)

    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(glyphsCount), 0, 0, 0)
}