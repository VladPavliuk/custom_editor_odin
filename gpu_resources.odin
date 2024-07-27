package main

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"

import "core:fmt"
import "core:os"
import "core:strings"

import "core:unicode/utf16"

TextureType :: enum {
    FONT,
}

GpuTexture :: struct {
    buffer: ^d3d11.ITexture2D,    
    srv: ^d3d11.IShaderResourceView,    
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

initGpuResources :: proc(directXState: ^DirectXState) {
    loadTextures(directXState)

    // testing
    vertexShader, blob := loadVertexShader("testVertexShader.hlsl", directXState)
    //defer vertexShader->Release()
    defer blob->Release()

    pixelShader := loadPixelShader("textPixelShader.hlsl", directXState)
    // defer pixelShader->Release()

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
    quadVertices[0] = VertexItem{ {-1.0, -1.0, 0.0}, {0.0, 1.0} } 
    quadVertices[1] = VertexItem{ {-1.0, 1.0, 0.0}, {0.0, 0.0} } 
    quadVertices[2] = VertexItem{ {1.0, 1.0, 0.0}, {1.0, 0.0} } 
    quadVertices[3] = VertexItem{ {1.0, -1.0, 0.0}, {1.0, 1.0} }

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
}

loadTextures :: proc(directXState: ^DirectXState) {
    directXState.textures[.FONT] = loadFont(directXState)
}

loadVertexShader :: proc(filePath: string, directXState: ^DirectXState) -> (^d3d11.IVertexShader, ^d3d11.IBlob) {
    blob: ^d3d11.IBlob
    errMessageBlob: ^d3d11.IBlob = nil
    defer if errMessageBlob != nil { errMessageBlob->Release() }

    fileContent, success := os.read_entire_file_from_filename(filePath)
    assert(success)
    defer delete(fileContent)
	hr := d3d_compiler.Compile(raw_data(fileContent), len(fileContent), strings.unsafe_string_to_cstring(filePath), nil, nil, 
        "main", "vs_5_0", 0, 0, &blob, &errMessageBlob)
    if errMessageBlob != nil {
        panic(string(cstring(errMessageBlob->GetBufferPointer())))
    } 
    assert(hr == 0)

    shader: ^d3d11.IVertexShader
    hr = directXState.device->CreateVertexShader(blob->GetBufferPointer(), blob->GetBufferSize(), nil, &shader)
    assert(hr == 0)

    return shader, blob
}

loadPixelShader :: proc(filePath: string, directXState: ^DirectXState) -> ^d3d11.IPixelShader {
    fileContent, success := os.read_entire_file_from_filename(filePath)
    assert(success)
    defer delete(fileContent)

    blob: ^d3d11.IBlob
    defer blob->Release()

    errMessageBlob: ^d3d11.IBlob = nil
    defer if errMessageBlob != nil { errMessageBlob->Release() }

    hr := d3d_compiler.Compile(raw_data(fileContent), len(fileContent), strings.unsafe_string_to_cstring(filePath), nil, nil, 
        "main", "ps_5_0", 0, 0, &blob, &errMessageBlob)
    if errMessageBlob != nil {
        panic(string(cstring(errMessageBlob->GetBufferPointer())))
    }
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
