package main

import "core:os"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import stbtt "vendor:stb/truetype"

loadFont :: proc(directXState: ^DirectXState) -> GpuTexture {
    fileContent, success := os.read_entire_file_from_filename("c:/windows/fonts/arial.TTF")
    assert(success)
    defer delete(fileContent)

    bitmapSize: int2 = { 512, 512 }
    
    charsData: [95]stbtt.bakedchar
    tmpFontBitmap := make([]byte, bitmapSize.x * bitmapSize.y)
    defer delete(tmpFontBitmap)
    overflow := stbtt.BakeFontBitmap(raw_data(fileContent), 0, 64.0, raw_data(tmpFontBitmap), bitmapSize.x, bitmapSize.y, 32, 95, raw_data(charsData[:]))

    textureDesc := d3d11.TEXTURE2D_DESC{
        Width = u32(bitmapSize.x), 
        Height = u32(bitmapSize.y),
        MipLevels = 1,
        ArraySize = 1,
        Format = dxgi.FORMAT.R8_UINT,
        SampleDesc = {
            Count = 1,
            Quality = 0,
        },
        Usage = d3d11.USAGE.DEFAULT,
        BindFlags = { d3d11.BIND_FLAG.SHADER_RESOURCE },
        CPUAccessFlags = {},
        MiscFlags = {},
    }

    data := d3d11.SUBRESOURCE_DATA{
        pSysMem = raw_data(tmpFontBitmap),
        SysMemPitch = u32(bitmapSize.x),
        SysMemSlicePitch = u32(bitmapSize.x * bitmapSize.y),
    }

    texture: ^d3d11.ITexture2D
    hr := directXState.device->CreateTexture2D(&textureDesc, &data, &texture)
    assert(hr == 0)
    
    srvDesc := d3d11.SHADER_RESOURCE_VIEW_DESC{
        Format = textureDesc.Format,
        ViewDimension = d3d11.SRV_DIMENSION.TEXTURE2D,
        Texture2D = {
            MipLevels = 1,
        },
    }

    srv: ^d3d11.IShaderResourceView
    hr = directXState.device->CreateShaderResourceView(texture, &srvDesc, &srv)
    assert(hr == 0)

    return GpuTexture{ texture, srv }
    // font: stbtt.fontinfo
    // res := stbtt.InitFont(&font, raw_data(fileContent[:]), 0)
    // assert(res == true)

    // lineHeight: f32 = 80.0
    // fontScale := stbtt.ScaleForPixelHeight(&font, lineHeight)

    // ascent: i32
    // descent: i32
    // lineGap: i32
	// stbtt.GetFontVMetrics(&font, &ascent, &descent, &lineGap)

    // ascent = i32(f32(ascent) * fontScale)
    // descent = i32(f32(descent) * fontScale) 
    // lineGap = i32(f32(lineGap) * fontScale)

}