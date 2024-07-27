package main

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

render :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    ctx := directXState.ctx

    ctx->ClearRenderTargetView(directXState.backBufferView, &[?]f32{windowData.a, 0.5, 1.0, 1.0})
    ctx->ClearDepthStencilView(directXState.depthBufferView, { .DEPTH, .STENCIL }, 1.0, 0)
    
    ctx->OMSetRenderTargets(1, &directXState.backBufferView, directXState.depthBufferView)
    ctx->OMSetDepthStencilState(directXState.depthStencilState, 0)
    ctx->RSSetState(directXState.rasterizerState)
    ctx->OMSetBlendState(directXState.blendState, nil, 0xFFFFFFFF)

	ctx->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)

    ctx->IASetInputLayout(directXState.inputLayouts[.POSITION_AND_TEXCOORD])
    ctx->VSSetShader(directXState.vertexShaders[.QUAD], nil, 0)
    ctx->PSSetShader(directXState.pixelShaders[.QUAD], nil, 0)

    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)

    offsets := [?]u32{ 0 }
    strideSize := [?]u32{directXState.vertexBuffers[.QUAD].strideSize}
	ctx->IASetVertexBuffers(0, 1, &directXState.vertexBuffers[.QUAD].gpuBuffer, raw_data(strideSize[:]), raw_data(offsets[:]))
	ctx->IASetIndexBuffer(directXState.indexBuffers[.QUAD].gpuBuffer, dxgi.FORMAT.R32_UINT, 0)
    
    ctx->DrawIndexed(6, 0, 0)

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}