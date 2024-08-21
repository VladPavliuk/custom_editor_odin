package main

import "core:mem"
import "core:os"
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import stbtt "vendor:stb/truetype"

FontGlyphGpu :: struct {
    sourceRect: Rect,
    targetTransformation: mat4,
}

FontChar :: struct {
    rect: Rect,
    offset: float2,
    xAdvance: f32,
}

FontData :: struct {
    //ttfFile: []byte,
	ascent: f32,
	descent: f32,
	lineGap: f32,
    lineHeight: f32,
	scale: f32,

    chars: map[rune]FontChar,
    kerningTable: map[rune]map[rune]f32,
}

loadFont :: proc(directXState: ^DirectXState) -> (GpuTexture, FontData) {
    fileContent, success := os.read_entire_file_from_filename("c:/windows/fonts/arial.TTF")
    assert(success)
    // defer delete(fontData.ttfFile)

    bitmapSize: int2 = { 512, 512 }
    
    // fontChars := make(map[u16]FontChar)
    // charsData: [95]stbtt.bakedchar
    tmpFontBitmap := make([]byte, bitmapSize.x * bitmapSize.y)
    defer delete(tmpFontBitmap)
    // overflow := stbtt.BakeFontBitmap(raw_data(fileContent), 0, 28.0, raw_data(tmpFontBitmap), bitmapSize.x, bitmapSize.y, 32, 95, raw_data(charsData[:]))

    alphabet := "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя !\"#$%&'()*+,-./0123456789:;<=>?@[\\]^_`{|}~ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    fontData := BakeFontBitmapCustomChars(fileContent, 20.0, tmpFontBitmap, bitmapSize, alphabet)

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

    return GpuTexture{ texture, srv, bitmapSize }, fontData
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

BakeFontBitmapCustomChars :: proc(data: []byte, pixelHeight: f32, bitmap: []byte, bitmapSize: int2, charsList: string) -> FontData {
    x, y, bottomY: i32
    font: stbtt.fontinfo

    if !stbtt.InitFont(&font, raw_data(data), 0) {
        panic("Error font parsing")
    }
    x = 1
    y = 1
	bottomY = 1

    ascent, descent, lineGap: i32
    stbtt.GetFontVMetrics(&font, &ascent, &descent, &lineGap)
    
    scale := stbtt.ScaleForPixelHeight(&font, pixelHeight)
    fontData := FontData{
        ascent = f32(ascent) * scale,
        descent = f32(descent) * scale,
        lineGap = f32(lineGap) * scale,
        scale = scale,
    }
    fontData.lineHeight = fontData.ascent - fontData.descent

    for char in charsList {
        advance, lsb, x0, y0, x1, y1, gw, gh: i32

        g := stbtt.FindGlyphIndex(&font, char)

        stbtt.GetGlyphHMetrics(&font, g, &advance, &lsb)
        stbtt.GetGlyphBitmapBox(&font, g, fontData.scale, fontData.scale, &x0, &y0, &x1, &y1)

        gw = x1 - x0
        gh = y1 - y0
        if x + gw + 1 >= bitmapSize.x {
            y = bottomY
            x = 1
        }
        if y + gh + 1 >= bitmapSize.y {
            panic("Bitmap size is nout enough to fit font")
        }

        bitmapOffset := mem.ptr_offset(raw_data(bitmap), x + y * bitmapSize.y)
        // xtest: f32
        // ytest: f32
        // stbtt.MakeGlyphBitmapSubpixelPrefilter(&font, bitmapOffset, gw, gh, bitmapSize.x, fontData.scale, fontData.scale, 2.0, 2.0, 2, 2, &xtest, &ytest, g)
        // stbtt.MakeGlyphBitmapSubpixel(&font, bitmapOffset, gw, gh, bitmapSize.x, fontData.scale, fontData.scale, 1.0, 1.0, g)
        stbtt.MakeGlyphBitmap(&font, bitmapOffset, gw, gh, bitmapSize.x, fontData.scale, fontData.scale, g)

        fontData.chars[char] = FontChar{
            rect = Rect{
                top = f32(y + gh),
                bottom = f32(y),
                left = f32(x),
                right = f32(x + gw),
            },
            offset = { f32(x0), f32(y0) },
            xAdvance = fontData.scale * f32(advance),
        }

        x = x + gw + 1
        if y + gh + 1 > bottomY {
            bottomY = y + gh + 1
        }
    }

    for aChar in fontData.chars {
        glyphKernings := make(map[rune]f32)

        for bChar in fontData.chars {
            glyphKernings[bChar] = f32(stbtt.GetCodepointKernAdvance(&font, aChar, bChar))
        }

        fontData.kerningTable[aChar] = glyphKernings
    }

    return fontData
}