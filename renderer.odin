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

    _renderCursor(directXState, windowData)

    @(static)
    timeElapsedTotal: f64 = 0.0
    
    @(static)
    timeElapsedCount: i32 = 0

    timer: time.Stopwatch
    time.stopwatch_start(&timer)
    _calculateTextLayout(directXState, windowData)
    _findCursorPosition(directXState, windowData)
    _updateCusrorData(directXState, windowData)

    _renderTestLine(directXState, windowData)    
    
    time.stopwatch_stop(&timer)
    elapsed := time.duration_microseconds(timer._accumulation)
    timeElapsedTotal += elapsed
    timeElapsedCount += 1
    fmt.printfln("Duration avg: %f", timeElapsedTotal / f64(timeElapsedCount))

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
}

_updateCusrorData :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    layoutLength := len(windowData.screenGlyphs.layout)
    if layoutLength == 0 { return }

    screenGlyphs := windowData.screenGlyphs

    //> update cursor position on screen
    // glyph := screenGlyphs.layout[windowData.inputState.selection[0]]
    
    // windowData.cursorScreenPosition.x = glyph.x
    // windowData.cursorScreenPosition.y = glyph.y

    // lastGlyph := windowData.screenGlyphs.layout[layoutLength - 1]
    // if i64(windowData.inputState.selection[0]) - 1 == lastGlyph.indexInString {
    //     windowData.cursorScreenPosition.x = lastGlyph.x + lastGlyph.width
    //     windowData.cursorScreenPosition.y = lastGlyph.y
    // }
    //<

    // find cursor line
    cursorLine := 0
    cursorIndex := i64(windowData.inputState.selection[0])
    for line, lineIndex in screenGlyphs.lines {
        leftGlyph := screenGlyphs.layout[line.x]
        rightGlyph := screenGlyphs.layout[line.y]

        if cursorIndex >= leftGlyph.indexInString && cursorIndex <= rightGlyph.indexInString {
            cursorLine = lineIndex 
            windowData.inputState.line_start = int(leftGlyph.indexInString)
            windowData.inputState.line_end = int(rightGlyph.indexInString)
            break
        }
    }

    cursorPosition := windowData.cursorScreenPosition

    if cursorLine > 0 {
        previousLine := screenGlyphs.lines[cursorLine - 1]

        windowData.inputState.up_index = int(screenGlyphs.layout[previousLine.y].indexInString)

        for glyphIndex in previousLine.x..<previousLine.y {
            if cursorPosition.x < screenGlyphs.layout[glyphIndex].x {
                windowData.inputState.up_index = int(screenGlyphs.layout[glyphIndex].indexInString)
                break
            }
        }
    }

    if cursorLine < len(screenGlyphs.lines) - 2 {
        nextLine := screenGlyphs.lines[cursorLine + 1]

        windowData.inputState.down_index = int(screenGlyphs.layout[nextLine.y].indexInString)

        for glyphIndex in nextLine.x..<nextLine.y {
            if cursorPosition.x < screenGlyphs.layout[glyphIndex].x {
                windowData.inputState.down_index = int(screenGlyphs.layout[glyphIndex].indexInString)
                break
            }
        }
    }

    // for ;cursorLine < len(screenGlyphs.lines); cursorLine += 1 {
    //     if screenGlyphs.lines[cursorLine].x <= cursorIndex && cursorIndex <= screenGlyphs.lines[cursorLine].x { 
    //         break 
    //     }
    // }

    // leftLineGlyph := screenGlyphs.lines[cursorLine].x
    // rightLineGlyph := screenGlyphs.lines[cursorLine].y
    
    // windowData.inputState.line_start = int(windowData.screenGlyphs.layout[leftLineGlyph].indexInString)
    // windowData.inputState.line_end = int(windowData.screenGlyphs.layout[rightLineGlyph].indexInString)
}

_renderCursor :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.BASIC], nil, 0)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
    ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    cursorHeight := directXState.fontData.ascent - directXState.fontData.descent
    modelMatrix := getTransformationMatrix(
        { windowData.cursorScreenPosition.x, windowData.cursorScreenPosition.y, 0.0 }, 
        { 0.0, 0.0, 0.0 }, { 3.0, cursorHeight, 1.0 })

    updateGpuBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION], directXState)

    directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)
    // testColor := float4{}
    // updateConstantBuffer(&fontChar, directXState.constantBuffers[.COLOR], directXState)
}

_findCursorPosition :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    if !windowData.isLeftMouseButtonDown { return }
    lineHeight := directXState.fontData.ascent - directXState.fontData.descent

    lineIndex := i16(windowData.mousePosition.y / lineHeight)
    
    // if user clicks lower on the screen where text was rendered take last line
    lineIndex = min(i16(len(windowData.screenGlyphs.lines) - 1), lineIndex)

    leftIndex := windowData.screenGlyphs.lines[lineIndex].x
    rightIndex := windowData.screenGlyphs.lines[lineIndex].y
    
    // by default move the cursor to the last glyph
    lastGlyph := windowData.screenGlyphs.layout[int(rightIndex)]
    windowData.inputState.selection = {int(lastGlyph.indexInString), int(lastGlyph.indexInString)}

    for i in leftIndex..<rightIndex {
        glyph := windowData.screenGlyphs.layout[int(i)]
        if windowData.mousePosition.x - f32(windowData.size.x / 2) < glyph.x {
            windowData.inputState.selection = {int(glyph.indexInString), int(glyph.indexInString)}
            break
        }
    }
}

// BENCHMARKS: +-200 microseconds with -speed build option
_calculateTextLayout :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    // NOTE: FOR NOW WE ASSUME THAT WRAPPING IS TURNED ON ALWAYS
    clear(&windowData.screenGlyphs.layout)
    clear(&windowData.screenGlyphs.lines)

    // stringToRender := windowData.testInputString.buf
    stringToRender := strings.to_string(windowData.testInputString)

    lineHeight := directXState.fontData.ascent - directXState.fontData.descent
    initialPosition: float2 = { -f32(windowData.size.x) / 2.0, f32(windowData.size.y) / 2.0 - lineHeight }
    cursorPosition := initialPosition
    lineBoundaryIndexes: int2 = { 0, 0 }

    startFromIndex: int = 0
    // append(&windowData.screenGlyphs.lines, startFromIndex)

    stringLength := len(stringToRender)
    charIndex := startFromIndex
    charSize := 1
    runeIndex := 0
    for ;charIndex < stringLength; charIndex += charSize {
        defer runeIndex += 1
        char: rune
        char, charSize = utf8.decode_rune(stringToRender[charIndex:])

        // defer { charIndex += size }

        // if cursor moves outside of the screen, stop layout generation
        if cursorPosition.y < -f32(windowData.size.y) / 2 {
            break
        }

        if char == '\n' {
            append(&windowData.screenGlyphs.layout, GlyphItem{
                char = char,
                indexInString = i64(charIndex),
                x = cursorPosition.x,
                y = cursorPosition.y,
                width = -1,
                height = -1,
            })

            cursorPosition.y -= lineHeight
            cursorPosition.x = initialPosition.x
            
            lineBoundaryIndexes.y = i32(runeIndex)
            append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + 1
            continue 
        }

        fontChar := directXState.fontData.chars[char]

        kerning: f32 = 0.0
        if charIndex + 1 < len(stringToRender) {
            // kerning = directXState.fontData.kerningTable[char][rune(stringToRender[charIndex + 1])]
        }
        
        glyphSize: float2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
        glyphPosition: float2 = { cursorPosition.x + fontChar.offset.x + kerning, cursorPosition.y - glyphSize.y - fontChar.offset.y }

        // text wrapping
        if glyphPosition.x + glyphSize.x >= f32(windowData.size.x) / 2 {
            cursorPosition.y -= lineHeight
            cursorPosition.x = initialPosition.x

            // since we do text wrapping, line should end on the previous symbol
            lineBoundaryIndexes.y = i32(runeIndex) - 1
            append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + 1

            glyphPosition = { cursorPosition.x + fontChar.offset.x + kerning, cursorPosition.y - glyphSize.y - fontChar.offset.y }
        }

        append(&windowData.screenGlyphs.layout, GlyphItem{
            char = char,
            indexInString = i64(charIndex),
            x = glyphPosition.x,
            y = glyphPosition.y,
            width = glyphSize.x,
            height = glyphSize.y,
        })
        
        cursorPosition.x += fontChar.xAdvance + fontChar.offset.x
    }

    // add artificial glyph at the end of layout, so cursor can be rendered
    append(&windowData.screenGlyphs.layout, GlyphItem{
        char = ' ',
        indexInString = i64(len(stringToRender)),
        x = cursorPosition.x,
        y = cursorPosition.y,
        width = -1,
        height = -1,
    })

    lineBoundaryIndexes.y = i32(runeIndex)
    append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
}

// BENCHMARKS:
// +-20000 microseconds with -speed build option without instancing
// +-750 microseconds with -speed build option with instancing
_renderTestLine :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
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
        fontChar := directXState.fontData.chars[glyphItem.char]

        modelMatrix := getTransformationMatrix(
            { glyphItem.x, glyphItem.y, 0.0 }, 
            { 0.0, 0.0, 0.0 }, 
            { glyphItem.width, glyphItem.height, 1.0 },
        )

        fontsList[index] = FontGlyphGpu{
            sourceRect = fontChar.rect,
            targetTransformation = intrinsics.transpose(modelMatrix), 
        }

        if glyphItem.indexInString == i64(windowData.inputState.selection[0]) {
            windowData.cursorScreenPosition.x = glyphItem.x
            windowData.cursorScreenPosition.y = glyphItem.y
        }
    }

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST], directXState)
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(len(windowData.screenGlyphs.layout)), 0, 0, 0)
}