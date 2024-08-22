package main

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"

import "base:runtime"

import "core:mem"

import "core:unicode/utf16"

import win32 "core:sys/windows"

TextureType :: enum {
    FONT,
}

GpuTexture :: struct {
    buffer: ^d3d11.ITexture2D,    
    srv: ^d3d11.IShaderResourceView,
    size: int2,  
}

GpuBufferType :: enum {
    QUAD,
}

GpuStructuredBufferType :: enum {
    GLYPHS_LIST,
    RECTS_LIST,
}

GpuBuffer :: struct {
	gpuBuffer: ^d3d11.IBuffer,
    srv: ^d3d11.IShaderResourceView,
	cpuBuffer: rawptr,
    length: u32,
    strideSize: u32,
	itemType: typeid,
}

VertexShaderType :: enum {
    BASIC,
    MULTIPLE_RECTS,
    FONT,
}

PixelShaderType :: enum {
    SOLID_COLOR,
    FONT,
}

InputLayoutType :: enum {
    POSITION_AND_TEXCOORD,
}

GpuConstantBufferType :: enum {
    FONT_GLYPH_LOCATION,
    PROJECTION,
    MODEL_TRANSFORMATION,
    COLOR,
}

initGpuResources :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    loadTextures(directXState, windowData)

    vertexShader, blob := loadVertexShader("shaders/basic_vs.fxc", directXState)
    defer blob->Release()

    inputLayoutDesc := [?]d3d11.INPUT_ELEMENT_DESC{
        { "POSITION", 0, dxgi.FORMAT.R32G32B32_FLOAT, 0, 0, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0 },
        { "TEXCOORD", 0, dxgi.FORMAT.R32G32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0 },
    }

    inputLayout: ^d3d11.IInputLayout
    hr := directXState.device->CreateInputLayout(raw_data(inputLayoutDesc[:]), len(inputLayoutDesc), blob->GetBufferPointer(), blob->GetBufferSize(), &inputLayout)
    assert(hr == 0)

    directXState.vertexShaders[.BASIC] = vertexShader 
    directXState.vertexShaders[.FONT], _ = loadVertexShader("shaders/font_vs.fxc", directXState)
    directXState.vertexShaders[.MULTIPLE_RECTS], _ = loadVertexShader("shaders/multiple_rects_vs.fxc", directXState)
    directXState.pixelShaders[.FONT] = loadPixelShader("shaders/font_ps.fxc", directXState)
    directXState.pixelShaders[.SOLID_COLOR] = loadPixelShader("shaders/solid_color_ps.fxc", directXState)
    directXState.inputLayouts[.POSITION_AND_TEXCOORD] = inputLayout 
    
    VertexItem :: struct {
        position: float3,
        texcoord: float2,
    }

    quadVertices := make([]VertexItem, 4)
    quadVertices[0] = VertexItem{ {0.0, 0.0, 0.0}, {0.0, 1.0} } 
    quadVertices[1] = VertexItem{ {0.0, 1.0, 0.0}, {0.0, 0.0} } 
    quadVertices[2] = VertexItem{ {1.0, 1.0, 0.0}, {1.0, 0.0} } 
    quadVertices[3] = VertexItem{ {1.0, 0.0, 0.0}, {1.0, 1.0} }

    directXState.vertexBuffers[.QUAD] = createVertexBuffer(quadVertices[:], directXState)
    
    indices := make([]u32, 6)
    indices[0] = 0 
    indices[1] = 1 
    indices[2] = 2
    indices[3] = 0
    indices[4] = 2
    indices[5] = 3
    // indices := []u32{
    //     0,1,2,
    //     0,2,3,
    // }
    directXState.indexBuffers[.QUAD] = createIndexBuffer(indices[:], directXState)

    directXState.constantBuffers[.FONT_GLYPH_LOCATION] = createConstantBuffer(FontChar, nil, directXState)

    // camera
    viewMatrix := getOrthoraphicsMatrix(f32(windowData.size.x), f32(windowData.size.y), 0.1, 10.0)
    directXState.constantBuffers[.PROJECTION] = createConstantBuffer(mat4, &viewMatrix, directXState)

    directXState.constantBuffers[.MODEL_TRANSFORMATION] = createConstantBuffer(mat4, nil, directXState)
    directXState.constantBuffers[.COLOR] = createConstantBuffer(float4, &float4{ 0.0, 0.0, 0.0, 1.0 }, directXState)

    fontGlyphs := make([]FontGlyphGpu, 15000)
    directXState.structuredBuffers[.GLYPHS_LIST] = createStructuredBuffer(fontGlyphs, directXState)

    rectsList := make([]mat4, 15000)
    directXState.structuredBuffers[.RECTS_LIST] = createStructuredBuffer(rectsList, directXState)
}

memoryAsSlice :: proc($T: typeid, pointer: rawptr, #any_int length: int) -> []T {
    return transmute([]T)runtime.Raw_Slice{pointer, length}
}

loadTextures :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    directXState.textures[.FONT], windowData.font = loadFont(directXState)
}

loadVertexShader :: proc(filePath: string, directXState: ^DirectXState) -> (^d3d11.IVertexShader, ^d3d11.IBlob) {
    blob: ^d3d11.IBlob
    
    hr := d3d_compiler.ReadFileToBlob(win32.utf8_to_wstring(filePath), &blob)
    assert(hr == 0)

    shader: ^d3d11.IVertexShader
    hr = directXState.device->CreateVertexShader(blob->GetBufferPointer(), blob->GetBufferSize(), nil, &shader)
    assert(hr == 0)

    return shader, blob
}

loadPixelShader :: proc(filePath: string, directXState: ^DirectXState) -> ^d3d11.IPixelShader {
    blob: ^d3d11.IBlob
    defer blob->Release()

    filePathBuffer: [255]u16
    utf16.encode_string(filePathBuffer[:], filePath)

    hr := d3d_compiler.ReadFileToBlob(raw_data(filePathBuffer[:]), &blob)
    assert(hr == 0)

    shader: ^d3d11.IPixelShader
    hr = directXState.device->CreatePixelShader(blob->GetBufferPointer(), blob->GetBufferSize(), nil, &shader)
    assert(hr == 0)

    return shader   
}

createVertexBuffer :: proc(items: []$T, directXState: ^DirectXState) -> GpuBuffer {
    bufferDesc := d3d11.BUFFER_DESC{
        ByteWidth = u32(len(items) * size_of(T)),
        Usage = d3d11.USAGE.DEFAULT,
        BindFlags = {d3d11.BIND_FLAG.VERTEX_BUFFER},
        CPUAccessFlags = {},
        MiscFlags = {},
        StructureByteStride = size_of(T),
    }

    data := d3d11.SUBRESOURCE_DATA{
        pSysMem = raw_data(items[:]),
    }

    buffer: ^d3d11.IBuffer
    hr := directXState.device->CreateBuffer(&bufferDesc, &data, &buffer)
    assert(hr == 0)

    return GpuBuffer{
        cpuBuffer = raw_data(items[:]),
        gpuBuffer = buffer,
        length = u32(len(items)),
        strideSize = size_of(T),
        itemType = typeid_of(T),
    }
}

createIndexBuffer :: proc(indices: []u32, directXState: ^DirectXState) -> GpuBuffer {
    bufferDesc := d3d11.BUFFER_DESC{
        ByteWidth = u32(len(indices) * size_of(u32)),
        Usage = d3d11.USAGE.DEFAULT,
        BindFlags = {d3d11.BIND_FLAG.INDEX_BUFFER},
        CPUAccessFlags = {},
        MiscFlags = {},
        StructureByteStride = size_of(u32),
    }

    data := d3d11.SUBRESOURCE_DATA{
        pSysMem = raw_data(indices[:]),
    }

    buffer: ^d3d11.IBuffer
    hr := directXState.device->CreateBuffer(&bufferDesc, &data, &buffer)
    assert(hr == 0)

    return GpuBuffer{
        cpuBuffer = raw_data(indices[:]),
        gpuBuffer = buffer,
        length = u32(len(indices)),
        strideSize = size_of(u32),
        itemType = typeid_of(u32),
    }
}

createConstantBuffer :: proc($T: typeid, initialData: ^T, directXState: ^DirectXState) -> GpuBuffer {
    bufferSize: u32 = size_of(T)

    desc := d3d11.BUFFER_DESC{
        ByteWidth = bufferSize + (16 - bufferSize % 16),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = {d3d11.BIND_FLAG.CONSTANT_BUFFER},
        CPUAccessFlags = {.WRITE},
        MiscFlags = {},
    }
    
    data := d3d11.SUBRESOURCE_DATA{}

    hr: d3d11.HRESULT
    buffer: ^d3d11.IBuffer
    if (initialData != nil) {
        data.pSysMem = initialData
        hr = directXState.device->CreateBuffer(&desc, &data, &buffer)
    } else {
        hr = directXState.device->CreateBuffer(&desc, nil, &buffer)
    }
    assert(hr == 0)

    return GpuBuffer {
        gpuBuffer = buffer,
        cpuBuffer = nil,
        length = 1,
        strideSize = desc.ByteWidth,
        itemType = T,
    }
}

updateGpuBuffer :: proc{updateGpuBuffer_SingleItem, updateGpuBuffer_ArrayItems}

updateGpuBuffer_SingleItem :: proc(data: ^$T, buffer: GpuBuffer, directXState: ^DirectXState) {
    sb: d3d11.MAPPED_SUBRESOURCE
    hr := directXState.ctx->Map(buffer.gpuBuffer, 0, d3d11.MAP.WRITE_DISCARD, {}, &sb)
    defer directXState.ctx->Unmap(buffer.gpuBuffer, 0)

    assert(hr == 0)
    mem.copy(sb.pData, data, size_of(data^))
}

updateGpuBuffer_ArrayItems :: proc(data: []$T, buffer: GpuBuffer, directXState: ^DirectXState) {
    sb: d3d11.MAPPED_SUBRESOURCE
    hr := directXState.ctx->Map(buffer.gpuBuffer, 0, d3d11.MAP.WRITE_DISCARD, {}, &sb)
    defer directXState.ctx->Unmap(buffer.gpuBuffer, 0)

    assert(hr == 0)
    mem.copy(sb.pData, raw_data(data[:]), len(data) * size_of(T))
}

createStructuredBuffer :: proc{createStructuredBuffer_InitData, createStructuredBuffer_NoInitData}

createStructuredBuffer_InitData :: proc(items: []$T, directXState: ^DirectXState) -> GpuBuffer {
    bufferDesc := d3d11.BUFFER_DESC{
        ByteWidth = u32(len(items) * size_of(T)),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = {d3d11.BIND_FLAG.SHADER_RESOURCE},
        CPUAccessFlags = {.WRITE},
        MiscFlags = {.BUFFER_STRUCTURED},
        StructureByteStride = size_of(T),
    }

    data := d3d11.SUBRESOURCE_DATA{
        pSysMem = raw_data(items[:]),
    }

    buffer: ^d3d11.IBuffer
    hr := directXState.device->CreateBuffer(&bufferDesc, &data, &buffer)
    assert(hr == 0)

    srvDesc := d3d11.SHADER_RESOURCE_VIEW_DESC{
        Format = .UNKNOWN,
        ViewDimension = .BUFFER,
        Buffer = {
            FirstElement = 0,
            NumElements = u32(len(items)),
        },
    }

    srv: ^d3d11.IShaderResourceView
    hr = directXState->device->CreateShaderResourceView(buffer, &srvDesc, &srv)
    assert(hr == 0)

    return GpuBuffer{
        cpuBuffer = raw_data(items),
        gpuBuffer = buffer,
        srv = srv,
        length = u32(len(items)),
        strideSize = size_of(T),
        itemType = typeid_of(T),
    }
}

createStructuredBuffer_NoInitData :: proc(length: u32, $T: typeid, directXState: ^DirectXState) -> GpuBuffer {
    bufferDesc := d3d11.BUFFER_DESC{
        ByteWidth = length * size_of(T),
        Usage = d3d11.USAGE.DYNAMIC,
        BindFlags = {d3d11.BIND_FLAG.SHADER_RESOURCE},
        CPUAccessFlags = {.WRITE},
        MiscFlags = {.BUFFER_STRUCTURED},
        StructureByteStride = size_of(T),
    }

    buffer: ^d3d11.IBuffer
    hr := directXState.device->CreateBuffer(&bufferDesc, nil, &buffer)
    assert(hr == 0)

    srvDesc := d3d11.SHADER_RESOURCE_VIEW_DESC{
        Format = .UNKNOWN,
        ViewDimension = .BUFFER,
        Buffer = {
            FirstElement = 0,
            NumElements = length,
        },
    }

    srv: ^d3d11.IShaderResourceView
    hr = directXState->device->CreateShaderResourceView(buffer, &srvDesc, &srv)
    assert(hr == 0)

    return GpuBuffer{
        cpuBuffer = nil,
        gpuBuffer = buffer,
        srv = srv,
        length = length,
        strideSize = size_of(T),
        itemType = typeid_of(T),
    }
}
