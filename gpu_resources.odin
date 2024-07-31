package main

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"

import "core:fmt"
import "core:os"
import "core:strings"
import "core:mem"

import "core:unicode/utf16"

import "core:math"

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

GpuBuffer :: struct {
	gpuBuffer: ^d3d11.IBuffer,
	cpuBuffer: rawptr,
    length: u32,
    strideSize: u32,
	itemType: typeid,
}

VertexShaderType :: enum {
    QUAD,
}

PixelShaderType :: enum {
    QUAD,
}

InputLayoutType :: enum {
    POSITION_AND_TEXCOORD,
}

GpuConstantBufferType :: enum {
    FONT_GLYPH_LOCATION,
    PROJECTION,
    MODEL_TRANSFORMATION,
}

initGpuResources :: proc(directXState: ^DirectXState) {
    loadTextures(directXState)

    vertexShader, blob := loadVertexShader("shaders/basic_vs.fxc", directXState)
    defer blob->Release()

    pixelShader := loadPixelShader("shaders/font_ps.fxc", directXState)

    inputLayoutDesc := [?]d3d11.INPUT_ELEMENT_DESC{
        { "POSITION", 0, dxgi.FORMAT.R32G32B32_FLOAT, 0, 0, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0 },
        { "TEXCOORD", 0, dxgi.FORMAT.R32G32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT, d3d11.INPUT_CLASSIFICATION.VERTEX_DATA, 0 },
    }

    inputLayout: ^d3d11.IInputLayout
    hr := directXState.device->CreateInputLayout(raw_data(inputLayoutDesc[:]), len(inputLayoutDesc), blob->GetBufferPointer(), blob->GetBufferSize(), &inputLayout)
    assert(hr == 0)

    directXState.vertexShaders[.QUAD] = vertexShader 
    directXState.pixelShaders[.QUAD] = pixelShader 
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
    viewMatrix := getOrthoraphicsMatrix(800, 800, 0.1, 10.0)
    directXState.constantBuffers[.PROJECTION] = createConstantBuffer(mat4, &viewMatrix, directXState)

    //modelMatrix := getScaleMatrix(3, 3, 1) * getTranslationMatrix(20, 0, 0) * getRotationMatrix(math.PI, 0, 0)
    directXState.constantBuffers[.MODEL_TRANSFORMATION] = createConstantBuffer(mat4, nil, directXState)
}

loadTextures :: proc(directXState: ^DirectXState) {
    directXState.textures[.FONT], directXState.fontData = loadFont(directXState)
}

loadVertexShader :: proc(filePath: string, directXState: ^DirectXState) -> (^d3d11.IVertexShader, ^d3d11.IBlob) {
    blob: ^d3d11.IBlob

    filePathBuffer: [255]u16
    utf16.encode_string(filePathBuffer[:], filePath)

    hr := d3d_compiler.ReadFileToBlob(raw_data(filePathBuffer[:]), &blob)
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

updateConstantBuffer :: proc(data: ^$T, buffer: GpuBuffer, directXState: ^DirectXState) {
    sb: d3d11.MAPPED_SUBRESOURCE
    hr := directXState.ctx->Map(buffer.gpuBuffer, 0, d3d11.MAP.WRITE_DISCARD, {}, &sb)
    defer directXState.ctx->Unmap(buffer.gpuBuffer, 0)

    assert(hr == 0)
    mem.copy(sb.pData, data, size_of(data^))
}
