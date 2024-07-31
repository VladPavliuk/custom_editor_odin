package main

import "core:strings"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

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
    
    ctx->VSSetShader(directXState.vertexShaders[.QUAD], nil, 0)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
    ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.QUAD], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.FONT_GLYPH_LOCATION].gpuBuffer)

    offsets := [?]u32{ 0 }
    strideSize := [?]u32{directXState.vertexBuffers[.QUAD].strideSize}
	ctx->IASetVertexBuffers(0, 1, &directXState.vertexBuffers[.QUAD].gpuBuffer, raw_data(strideSize[:]), raw_data(offsets[:]))
	ctx->IASetIndexBuffer(directXState.indexBuffers[.QUAD].gpuBuffer, dxgi.FORMAT.R32_UINT, 0)
    
    _renderTestLine(directXState, windowData)
    // ctx->DrawIndexed(6, 0, 0)

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}

_renderCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    
}

_renderTestLine :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    testString := strings.to_string(windowData.testInputString)
    // testString := "Lorem ipsum dolor sit amet,\nconsectetur adipiscing elit"

    initialPosition: float2 = { -f32(windowData.size.x) / 2.0, f32(windowData.size.y) / 2.0 - directXState.fontData.ascent }
    cursorPosition := initialPosition

    for char, charIndex in testString {
        if char == '\n' { 
            cursorPosition.y -= directXState.fontData.ascent - directXState.fontData.descent
            cursorPosition.x = initialPosition.x
            continue 
        }

        fontChar := directXState.fontData.chars[char]

        updateConstantBuffer(&fontChar, directXState.constantBuffers[.FONT_GLYPH_LOCATION], directXState)

        kerning: f32 = 0.0
        if charIndex + 1 < len(testString) {
            kerning = directXState.fontData.kerningTable[char][rune(testString[charIndex + 1])]
        }

        size: float2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
        modelMatrix := getScaleMatrix(size.x, size.y, 1) *
            getTranslationMatrix(cursorPosition.x + fontChar.offset.x + kerning, cursorPosition.y - size.y - fontChar.offset.y, 0) * 
            getRotationMatrix(0, 0, 0)

        updateConstantBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION], directXState)

        directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)

        cursorPosition.x += fontChar.xAdvance + fontChar.offset.x

    }
}