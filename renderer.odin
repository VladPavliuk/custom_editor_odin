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
    calculateLayout(windowData)

    findCursorPosition(windowData)
    updateCusrorData(windowData)
    
    time.stopwatch_stop(&timer)
    elapsed := time.duration_microseconds(timer._accumulation)
    timeElapsedTotal += elapsed
    timeElapsedCount += 1
    fmt.printfln("Duration avg: %f", timeElapsedTotal / f64(timeElapsedCount))
    
    renderCursor(directXState, windowData)
    renderText(directXState, windowData)    

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}

renderCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    drawCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData, indexIndexLayout: i32) {
        assert(indexIndexLayout != -1)
        assert(indexIndexLayout < i32(len(windowData.screenGlyphs.layout)))
        ctx := directXState.ctx

        ctx->VSSetShader(directXState.vertexShaders[.BASIC], nil, 0)
        ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
        ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)
    
        ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
        ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)
    
        cursorScreenPosition := windowData.screenGlyphs.layout[indexIndexLayout]
    
        modelMatrix := getTransformationMatrix(
            { cursorScreenPosition.x, cursorScreenPosition.y, 0.0 }, 
            { 0.0, 0.0, 0.0 }, { 3.0, windowData.font.lineHeight, 1.0 })
    
        updateGpuBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION], directXState)
    
        directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)
        
        // testColor := float4{}
        // updateConstantBuffer(&fontChar, directXState.constantBuffers[.COLOR], directXState)
    }

    selection := windowData.screenGlyphs.cursorLayoutSelection

    // selection is outside of layout
    if selection.x == -1 && selection.y == -1 { return }

    // selection start "before" layout
    if selection.x == -1 && selection.y >= 0 {
        drawCursor(directXState, windowData, windowData.screenGlyphs.cursorLayoutSelection.y)
    }

    // selection end "after" layout
    if selection.x >= 0 && selection.y == -1 {
        drawCursor(directXState, windowData, windowData.screenGlyphs.cursorLayoutSelection.x)
    }
    
    // selection "inside" layout
    if selection.x >= 0 && selection.y >= 0 {
        drawCursor(directXState, windowData, windowData.screenGlyphs.cursorLayoutSelection.x)
        drawCursor(directXState, windowData, windowData.screenGlyphs.cursorLayoutSelection.y)
    }
    
}

// BENCHMARKS:
// +-20000 microseconds with -speed build option without instancing
// +-750 microseconds with -speed build option with instancing
renderText :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)

    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)

    for glyphItem, index in windowData.screenGlyphs.layout {
        assert(u32(index) < fontListBuffer.length, "Number of glyphs on screen exceeded the threshold")
        fontChar := windowData.font.chars[glyphItem.char]

        modelMatrix := getTransformationMatrix(
            { glyphItem.x, glyphItem.y, 0.0 }, 
            { 0.0, 0.0, 0.0 }, 
            { glyphItem.width, glyphItem.height, 1.0 },
        )

        fontsList[index] = FontGlyphGpu{
            sourceRect = fontChar.rect,
            targetTransformation = intrinsics.transpose(modelMatrix), 
        }
    }

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(len(windowData.screenGlyphs.layout)), 0, 0, 0)
}