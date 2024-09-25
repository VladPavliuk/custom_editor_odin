package main

import "core:strings"

import "base:intrinsics"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "core:unicode/utf8"

import "core:math"
import "core:strconv"

import "core:text/edit"

// TODO: make all them configurable
RED_COLOR := float4{ 1.0, 0.0, 0.0, 1.0 }
GREEN_COLOR := float4{ 0.0, 1.0, 0.0, 1.0 }
BLUE_COLOR := float4{ 0.0, 0.0, 1.0, 1.0 }
YELLOW_COLOR := float4{ 1.0, 1.0, 0.0, 1.0 }
WHITE_COLOR := float4{ 1.0, 1.0, 1.0, 1.0 }
BLACK_COLOR := float4{ 0.0, 0.0, 0.0, 1.0 }
LIGHT_GRAY_COLOR := float4{ 0.5, 0.5, 0.5, 1.0 }
GRAY_COLOR := float4{ 0.3, 0.3, 0.3, 1.0 }
DARKER_GRAY_COLOR := float4{ 0.2, 0.2, 0.2, 1.0 }
DARK_GRAY_COLOR := float4{ 0.1, 0.1, 0.1, 1.0 }

EDITOR_BG_COLOR := float4{ 0.0, 0.25, 0.5, 1.0 }
CURSOR_COLOR := float4{ 0.0, 0.0, 0.0, 1.0 }
CURSOR_LINE_BG_COLOR := float4{ 1.0, 1.0, 1.0, 0.1 }
LINE_NUMBERS_BG_COLOR := float4{ 0.0, 0.0, 0.0, 0.3 }
TEXT_SELECTION_BG_COLOR := float4{ 1.0, 0.5, 1.0, 0.3 }

THEME_COLOR_1 := float4{ 251 / 255.0, 133 / 255.0, 0 / 255.0, 1.0 }
THEME_COLOR_2 := float4{ 251 / 255.0, 183 / 255.0, 0 / 255.0, 1.0 }
THEME_COLOR_3 := float4{ 2 / 255.0, 48 / 255.0, 71 / 255.0, 1.0 }
THEME_COLOR_4 := float4{ 33 / 255.0, 158 / 255.0, 188 / 255.0, 1.0 }
THEME_COLOR_5 := float4{ 142 / 255.0, 202 / 255.0, 230 / 255.0, 1.0 }

render :: proc() {
    ctx := directXState.ctx

    bgColor: [4]f32 = EDITOR_BG_COLOR.xyzw
    ctx->ClearRenderTargetView(directXState.backBufferView, &bgColor)
    ctx->ClearDepthStencilView(directXState.depthBufferView, { .DEPTH, .STENCIL }, 1.0, 0)
    
    ctx->OMSetRenderTargets(1, &directXState.backBufferView, directXState.depthBufferView)
    ctx->OMSetDepthStencilState(directXState.depthStencilState, 0)
    ctx->RSSetState(directXState.rasterizerState)
	ctx->PSSetSamplers(0, 1, &directXState->samplerState)

    ctx->OMSetBlendState(directXState.blendState, nil, 0xFFFFFFFF)

	ctx->IASetPrimitiveTopology(d3d11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
    ctx->IASetInputLayout(directXState.inputLayouts[.POSITION_AND_TEXCOORD])

    offsets := [?]u32{ 0 }
    strideSize := [?]u32{directXState.vertexBuffers[.QUAD].strideSize}
	ctx->IASetVertexBuffers(0, 1, &directXState.vertexBuffers[.QUAD].gpuBuffer, raw_data(strideSize[:]), raw_data(offsets[:]))
	ctx->IASetIndexBuffer(directXState.indexBuffers[.QUAD].gpuBuffer, dxgi.FORMAT.R32_UINT, 0)

    //renderRectBorder(directXState, { -200, -200 }, {50,100}, 1.0, 1.0, GRAY_COLOR)
    // @(static)
    // timeElapsedTotal: f64 = 0.0
    
    // @(static)
    // timeElapsedCount: i32 = 0
 
    // timer: time.Stopwatch
    // time.stopwatch_start(&timer)    

    //> ui testing
    // setClipRect(Rect{
    //     top = 10,
    //     bottom = 200,
    //     left = 0,
    //     right = 200,
    // })
    uiStaff()
    // resetClipRect()
    //<

    // glyphsCount, selectionsCount := fillTextBuffer(&windowData.editorCtx, windowData.maxZIndex)

    // // if windowData.isInputMode {
    //     calculateLines(windowData.editableTextCtx)
    //     findCursorPosition(windowData.editableTextCtx)
    //     updateCusrorData(windowData.editableTextCtx)
    // // }
    // time.stopwatch_stop(&timer)
    
    // elapsed := time.duration_microseconds(timer._accumulation)
    // timeElapsedTotal += elapsed
    // timeElapsedCount += 1
    // // fmt.printfln("Duration avg: %f", timeElapsedTotal / f64(timeElapsedCount))
    
    renderLineNumbers()

    hr := directXState.swapchain->Present(1, {})
    assert(hr == 0)
    //TODO: if pc went to sleep mode hr variable might be not 0, investigate why is that
}

resetClipRect :: proc() {
    scissorRect := d3d11.RECT{
        top = 0,
        bottom = windowData.size.y,
        left = 0,
        right = windowData.size.x,
    }

    directXState.ctx->RSSetScissorRects(1, &scissorRect)
}

setClipRect :: proc(rect: Rect) {
    rect := rect
    rect = directXToScreenRect(rect)

    scissorRect := d3d11.RECT{
        top = rect.top,
        bottom = rect.bottom,
        left = rect.left,
        right = rect.right,
    }

    directXState.ctx->RSSetScissorRects(1, &scissorRect)
}

testingButtons :: proc() {
    if action := renderButton(&windowData.uiContext, UiTextButton{
        text = "Test 1",
        position = { 0, 0 },
        size = { 100, 30 },
        // color = WHITE_COLOR,
        bgColor = THEME_COLOR_3,
        // hoverBgColor = BLACK_COLOR,
    }); action != nil {
        fmt.print("Test 1 - ")

        if .SUBMIT in action { fmt.print("SUBMIT ") }
        if .HOT in action { fmt.print("HOT ") }
        if .ACTIVE in action { fmt.print("ACTIVE ") }
        if .GOT_ACTIVE in action { fmt.print("GOT_ACTIVE ") }
        if .LOST_ACTIVE in action { fmt.print("LOST_ACTIVE ") }
        if .MOUSE_ENTER in action { fmt.print("MOUSE_ENTER ") }
        if .MOUSE_LEAVE in action { fmt.print("MOUSE_LEAVE ") }
        if .GOT_FOCUS in action { fmt.print("GOT_FOCUS ") }
        if .LOST_FOCUS in action { fmt.print("LOST_FOCUS ") }

        fmt.print('\n')
    }

    if action := renderButton(&windowData.uiContext, UiTextButton{
        text = "Test 2",
        position = { 40, 10 },
        size = { 100, 30 },
        // color = WHITE_COLOR,
        bgColor = THEME_COLOR_1,
        // hoverBgColor = BLACK_COLOR,
    }); action != nil {
        fmt.print("Test 2 - ")

        if .SUBMIT in action { fmt.print("SUBMIT ") }
        if .HOT in action { fmt.print("HOT ") }
        if .ACTIVE in action { fmt.print("ACTIVE ") }
        if .GOT_ACTIVE in action { fmt.print("GOT_ACTIVE ") }
        if .LOST_ACTIVE in action { fmt.print("LOST_ACTIVE ") }
        if .MOUSE_ENTER in action { fmt.print("MOUSE_ENTER ") }
        if .MOUSE_LEAVE in action { fmt.print("MOUSE_LEAVE ") }
        if .GOT_FOCUS in action { fmt.print("GOT_FOCUS ") }
        if .LOST_FOCUS in action { fmt.print("LOST_FOCUS ") }

        fmt.print('\n')
    }
}

uiStaff :: proc() {
    beginUi(&windowData.uiContext, windowData.maxZIndex / 2.0)

    renderEditorContent()
    renderEditorFileTabs()

    // @(static)
    // isDropdownOpen := false

    // dropDonButtonActions := renderButton(&windowData.uiContext, UiTextButton{
    //     position = { -200, -100 }, size = { 150, 30 },
    //     text = "test dropdown",
    //     bgColor = THEME_COLOR_1,
    // }) 
    
    // if .SUBMIT in dropDonButtonActions {
    //     isDropdownOpen = !isDropdownOpen
    // }

    // beginDropdown(&windowData.uiContext, UiNewDropdown{
    //     position = { 0, -300 }, size = { 200, 300 },
    //     isOpen = &isDropdownOpen,
    //     bgColor = THEME_COLOR_2,
    // }, dropDonButtonActions)


    // endDropdown(&windowData.uiContext)

    // @(static)
    // showPanel := false
    
    // if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
    //     text = "Show/Hide panel",
    //     position = { 39, -100 },
    //     size = { 150, 30 },
    //     // color = WHITE_COLOR,
    //     bgColor = THEME_COLOR_4,
    //     // hoverBgColor = BLACK_COLOR,
    // }) { showPanel = !showPanel }
    
    // if showPanel {
    //     @(static)
    //     panelPosition: int2 = { -250, -100 } 

    //     @(static)
    //     panelSize: int2 = { 200, 300 }

    //     beginPanel(&windowData.uiContext, UiPanel{
    //         title = "PANEL 1",
    //         position = &panelPosition,
    //         size = &panelSize,
    //         bgColor = THEME_COLOR_1,
    //         // hoverBgColor = THEME_COLOR_5,
    //     }, &showPanel)

    //     @(static)
    //     checked := false
    //     renderCheckbox(&windowData.uiContext, UiCheckbox{
    //         text = "word wrapping",
    //         checked = &windowData.wordWrapping,
    //         position = { 0, 0 },
    //         color = WHITE_COLOR,
    //         bgColor = GREEN_COLOR,
    //         hoverBgColor = BLACK_COLOR,
    //     })
        // @(static)
        // testinItemCheckbox := false

        // testItems := []UiDropdownItem{
        //     {
        //         text = "item 1",
        //     },
        //     {
        //         text = "item 2",
        //         checkbox = &testinItemCheckbox,
        //     },
        //     {
        //         checkbox = &testinItemCheckbox,
        //     },
        //     {
        //         rightText = "item 4", 
        //     },
        //     {
        //         text = "item 5",
        //         rightText = "asdasd",
        //     },
        //     {
        //         text = "item 6asdsadasdasdadsasdsadsadsadasd",
        //     },
        //     {
        //         isSeparator = true,
        //     },
        //     {
        //         rightText = "item 7 loooooooooooooooooooooooooooong", 
        //     },
        // }
        // @(static)
        // selectedItem: i32 = 0
        // @(static)
        // dropdownScrollOffset: i32 = 0
        // @(static)
        // isOpen: bool = false
        // if actions, selected := renderDropdown(&windowData.uiContext, UiDropdown{
        //     // text = "YEAH",
        //     position = { 0, 100 }, size = { 120, 40 },
        //     items = testItems,
        //     bgColor = THEME_COLOR_2,
        //     selectedItemIndex = selectedItem,
        //     maxItemShow = 5,
        //     isOpen = &isOpen,
        //     scrollOffset = &dropdownScrollOffset,
        //     itemStyles = {
        //         size = { 200, 0 },
        //         padding = Rect{ top = 3, bottom = 3, left = 35, right = 5 },
        //         bgColor = THEME_COLOR_3,
        //         hoverColor = THEME_COLOR_4,
        //     },
        // }); .SUBMIT in actions {
        //     selectedItem = selected
        // }

    //     endPanel(&windowData.uiContext)
    // }

    // @(static)
    // offset: i32 = 0
    // renderVerticalScroll(windowData, UiScroll{
    //     bgRect = Rect{
    //         top = 150, bottom = -150,
    //         left = 50, right = 100,
    //     },
    //     offset = &offset,
    //     height = 30,
    //     color = THEME_COLOR_3,
    //     hoverColor = THEME_COLOR_2,
    //     bgColor = THEME_COLOR_1,
    // })

    renderTopMenu()

    endUi(&windowData.uiContext, windowData.delta)

    windowData.isInputMode = windowData.uiContext.activeId == {}
}

renderRect :: proc{renderRectVec_Float, renderRectVec_Int, renderRect_Int}

renderRect_Int :: proc(rect: Rect, zValue: f32, color: float4) {
    renderRectVec_Float({ f32(rect.left), f32(rect.bottom) }, 
        { f32(rect.right - rect.left), f32(rect.top - rect.bottom) }, zValue, color)
}

renderRectVec_Int :: proc(position, size: int2, zValue: f32, color: float4) {
    renderRectVec_Float({ f32(position.x), f32(position.y) }, { f32(size.x), f32(size.y) }, zValue, color)
}

renderRectVec_Float :: proc(position, size: float2, zValue: f32, color: float4) {
    color := color
    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.BASIC], nil, 0)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
    ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    modelMatrix := getTransformationMatrix(
        { position.x, position.y, zValue }, 
        { 0.0, 0.0, 0.0 }, { size.x, size.y, 1.0 })

    updateGpuBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION])
    updateGpuBuffer(&color, directXState.constantBuffers[.COLOR])

    directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)
}

renderImageRect :: proc{renderImageRectVec_Float, renderImageRectVec_Int, renderImageRect_Int}

renderImageRect_Int :: proc(rect: Rect, zValue: f32, texture: TextureType) {
    renderImageRectVec_Float({ f32(rect.left), f32(rect.bottom) }, 
        { f32(rect.right - rect.left), f32(rect.top - rect.bottom) }, zValue, texture)
}

renderImageRectVec_Int :: proc(position, size: int2, zValue: f32, texture: TextureType) {
    renderImageRectVec_Float({ f32(position.x), f32(position.y) }, { f32(size.x), f32(size.y) }, zValue, texture)
}

renderImageRectVec_Float :: proc(position, size: float2, zValue: f32, texture: TextureType) {
    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.BASIC], nil, 0)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)
    ctx->VSSetConstantBuffers(1, 1, &directXState.constantBuffers[.MODEL_TRANSFORMATION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.TEXTURE], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[texture].srv)

    modelMatrix := getTransformationMatrix(
        { position.x, position.y, zValue }, 
        { 0.0, 0.0, 0.0 }, { size.x, size.y, 1.0 })

    updateGpuBuffer(&modelMatrix, directXState.constantBuffers[.MODEL_TRANSFORMATION])

    directXState.ctx->DrawIndexed(directXState.indexBuffers[.QUAD].length, 0, 0)
}

renderRectBorder :: proc{renderRectBorderVec_Float, renderRectBorderVec_Int, renderRectBorder_Int}

renderRectBorder_Int :: proc(rect: Rect, thickness, zValue: f32, color: float4) {
    renderRectBorderVec_Float({ f32(rect.left), f32(rect.bottom) }, 
        { f32(rect.right - rect.left), f32(rect.top - rect.bottom) }, thickness, zValue, color)
}

renderRectBorderVec_Int :: proc(position, size: int2, thickness, zValue: f32, color: float4) {
    renderRectBorderVec_Float({ f32(position.x), f32(position.y) }, { f32(size.x), f32(size.y) }, thickness, zValue, color)
}

renderRectBorderVec_Float :: proc(position, size: float2, thickness, zValue: f32, color: float4) {
    renderRect(float2{ position.x, position.y + size.y - thickness }, float2{ size.x, thickness }, zValue, color) // top border
    renderRect(position, float2{ size.x, thickness }, zValue, color) // bottom border
    renderRect(position, float2{ thickness, size.y }, zValue, color) // left border
    renderRect(float2{ position.x + size.x - thickness, position.y }, float2{ thickness, size.y }, zValue, color) // right border
}

renderLine :: proc(text: string, font: ^FontData, position: int2, color: float4, zIndex: f32) {
    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)
    
    leftOffset := f32(position.x)
    topOffset := f32(position.y) - font.descent

    for char, index in text {
        fontChar := font.chars[char]

        glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
        glyphPosition: int2 = { i32(leftOffset) + fontChar.offset.x, i32(topOffset) - glyphSize.y - fontChar.offset.y }

        modelMatrix := getTransformationMatrix(
            { f32(glyphPosition.x), f32(glyphPosition.y), zIndex }, 
            { 0.0, 0.0, 0.0 }, 
            { f32(glyphSize.x), f32(glyphSize.y), 1.0 },
        )
        
        fontsList[index] = FontGlyphGpu{
            sourceRect = fontChar.rect,
            targetTransformation = intrinsics.transpose(modelMatrix), 
        }
        leftOffset += fontChar.xAdvance
    }

    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST])
    color := color // whithout it we won't be able to pass color as a pointer
    updateGpuBuffer(&color, directXState.constantBuffers[.COLOR])
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(len(text)), 0, 0, 0)
}

renderCursor :: proc(ctx: ^EditableTextContext, zIndex: f32) {
    // if cursor above top line, don't render it
    if ctx.cursorLineIndex < ctx.lineIndex { return }
    
    // TODO: move it into a separate function
    editorRectSize := getRectSize(ctx.rect)
    maxLinesOnScreen := editorRectSize.y / i32(windowData.font.lineHeight)

    // if cursor bellow bottom line, don't render it
    if ctx.cursorLineIndex > maxLinesOnScreen + ctx.lineIndex { return }

    topOffset := f32(ctx.rect.top) - f32(ctx.cursorLineIndex - ctx.lineIndex) * windowData.font.lineHeight
    topOffset -= windowData.font.lineHeight
    leftOffset := f32(ctx.rect.left) + ctx.cursorLeftOffset - f32(ctx.leftOffset)

    if leftOffset < f32(ctx.rect.left) || leftOffset > f32(ctx.rect.right) { return }

    renderRect(float2{ leftOffset, topOffset }, float2{ 3.0, windowData.font.lineHeight }, 
        zIndex, CURSOR_COLOR)
}

fillTextBuffer :: proc(ctx: ^EditableTextContext, zIndex: f32) -> (i32, i32) {
    //TODO: this looks f*ing stupid!
    shouldRenderCursor := windowData.editableTextCtx == ctx

    stringToRender := strings.to_string(ctx.text)

    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)

    rectsListBuffer := directXState.structuredBuffers[.RECTS_LIST]
    rectsList := memoryAsSlice(mat4, rectsListBuffer.cpuBuffer, rectsListBuffer.length)

    topLine := ctx.lineIndex
    bottomLine := i32(len(ctx.lines))

    editableRectSize := getRectSize(ctx.rect)

    glyphsCount := 0
    selectionsCount := 0
    hasSelection := ctx.editorState.selection[0] != ctx.editorState.selection[1]
    selectionRange: int2 = {
        i32(min(ctx.editorState.selection[0], ctx.editorState.selection[1])),
        i32(max(ctx.editorState.selection[0], ctx.editorState.selection[1])),
    }

    screenPosition := float2{ f32(ctx.rect.left), f32(ctx.rect.top) - windowData.font.ascent }
    
    if shouldRenderCursor {
        renderCursor(ctx, zIndex - 3.0)
    }

    for lineIndex in topLine..<bottomLine {
        if screenPosition.y < -f32(editableRectSize.y) / 2 {
            break
        }
        line := ctx.lines[lineIndex]

        screenPosition.x = f32(ctx.rect.left)

        if lineIndex == ctx.cursorLineIndex {
            renderRect(float2{ screenPosition.x, screenPosition.y + windowData.font.descent }, float2{ f32(editableRectSize.x), windowData.font.lineHeight }, zIndex, CURSOR_LINE_BG_COLOR)
        }

        byteIndex := line.x
        lineLeftOffset: f32 = 0.0
        for byteIndex <= line.y {
            // TODO: add RUNE_ERROR handling
            char, charSize := utf8.decode_rune(stringToRender[byteIndex:])
            defer byteIndex += i32(charSize)

            fontChar := windowData.font.chars[char]
            
            glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
            glyphPosition: int2 = { i32(screenPosition.x) + fontChar.offset.x, i32(screenPosition.y) - glyphSize.y - fontChar.offset.y }

            // NOTE: last symbol in string is EOF which has 0 length
            // TODO: optimize it
            if charSize == 0 { break }

            lineLeftOffset += fontChar.xAdvance

            if lineLeftOffset > f32(ctx.leftOffset + editableRectSize.x) { break } // stop line rendering if outside of line rigth boundary
            else if lineLeftOffset < f32(ctx.leftOffset) { continue } // don't render glyphs until their position is inside visible region 

            if hasSelection && byteIndex >= selectionRange.x && byteIndex < selectionRange.y  {
                rectsList[selectionsCount] = intrinsics.transpose(getTransformationMatrix(
                    { screenPosition.x, screenPosition.y, zIndex - 1.0 }, 
                    { 0.0, 0.0, 0.0 }, 
                    { fontChar.xAdvance, windowData.font.lineHeight, 1.0 },
                ))
                selectionsCount += 1
            }

            modelMatrix := getTransformationMatrix(
                { f32(glyphPosition.x), f32(glyphPosition.y), zIndex - 2.0 }, 
                { 0.0, 0.0, 0.0 }, 
                { f32(glyphSize.x), f32(glyphSize.y), 1.0 },
            )
            
            fontsList[glyphsCount] = FontGlyphGpu{
                sourceRect = fontChar.rect,
                targetTransformation = intrinsics.transpose(modelMatrix), 
            }
            glyphsCount += 1
        
            screenPosition.x += fontChar.xAdvance
        }
        
        screenPosition.y -= windowData.font.lineHeight
    }

    return i32(glyphsCount), i32(selectionsCount)
}

renderLineNumbers :: proc() {
    maxLinesOnScreen := i32(f32(getEditorSize().y) / windowData.font.lineHeight)

    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)
    
    // draw background
    renderRect(float2{ -f32(windowData.size.x) / 2.0, -f32(windowData.size.y) / 2.0 }, 
        float2{ f32(windowData.editorPadding.left), f32(windowData.size.y) }, windowData.maxZIndex, LINE_NUMBERS_BG_COLOR)

    topOffset := math.round(f32(windowData.size.y) / 2.0 - windowData.font.lineHeight) - f32(windowData.editorPadding.top)
    
    lineNumberStrBuffer: [255]byte
    glyphsCount := 0
    
    firstNumber := windowData.editorCtx.lineIndex + 1
    lastNumber := min(i32(len(windowData.editorCtx.lines)), windowData.editorCtx.lineIndex + maxLinesOnScreen)

    for lineIndex in firstNumber..=lastNumber {
        lineNumberStr := strconv.itoa(lineNumberStrBuffer[:], int(lineIndex))

        leftOffset := -f32(windowData.size.x) / 2.0

        for digit in lineNumberStr {
            fontChar := windowData.font.chars[digit]

            glyphSize: int2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
            glyphPosition: int2 = { i32(leftOffset) + fontChar.offset.x, i32(topOffset) - glyphSize.y - fontChar.offset.y }

            modelMatrix := getTransformationMatrix(
                { f32(glyphPosition.x), f32(glyphPosition.y), windowData.maxZIndex - 1.0 }, 
                { 0.0, 0.0, 0.0 }, 
                { f32(glyphSize.x), f32(glyphSize.y), 1.0 },
            )
            
            fontsList[glyphsCount] = FontGlyphGpu{
                sourceRect = fontChar.rect,
                targetTransformation = intrinsics.transpose(modelMatrix), 
            }
            glyphsCount += 1
            leftOffset += fontChar.xAdvance
        }

        topOffset -= windowData.font.lineHeight
    }

    ctx := directXState.ctx

    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST])
    updateGpuBuffer(&WHITE_COLOR, directXState.constantBuffers[.COLOR])
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(glyphsCount), 0, 0, 0)
}

// BENCHMARKS:
// +-20000 microseconds with -speed build option without instancing
// +-750 microseconds with -speed build option with instancing
renderText :: proc(glyphsCount: i32, selectionsCount: i32, textColor: float4, selectionColor: float4) {
    ctx := directXState.ctx

    //> draw selection
    rectsListBuffer := directXState.structuredBuffers[.RECTS_LIST]
    rectsList := memoryAsSlice(mat4, rectsListBuffer.cpuBuffer, rectsListBuffer.length)

    ctx->VSSetShader(directXState.vertexShaders[.MULTIPLE_RECTS], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.RECTS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.SOLID_COLOR], nil, 0)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    updateGpuBuffer(rectsList, directXState.structuredBuffers[.RECTS_LIST])
    selectionColor := selectionColor
    updateGpuBuffer(&selectionColor, directXState.constantBuffers[.COLOR])

    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(selectionsCount), 0, 0, 0)
    //<
    
    //> draw text
    fontListBuffer := directXState.structuredBuffers[.GLYPHS_LIST]
    fontsList := memoryAsSlice(FontGlyphGpu, fontListBuffer.cpuBuffer, fontListBuffer.length)
    
    ctx->VSSetShader(directXState.vertexShaders[.FONT], nil, 0)
    ctx->VSSetShaderResources(0, 1, &directXState.structuredBuffers[.GLYPHS_LIST].srv)
    ctx->VSSetConstantBuffers(0, 1, &directXState.constantBuffers[.PROJECTION].gpuBuffer)

    ctx->PSSetShader(directXState.pixelShaders[.FONT], nil, 0)
    ctx->PSSetShaderResources(0, 1, &directXState.textures[.FONT].srv)
    ctx->PSSetConstantBuffers(0, 1, &directXState.constantBuffers[.COLOR].gpuBuffer)

    textColor := textColor
    updateGpuBuffer(&textColor, directXState.constantBuffers[.COLOR])
    updateGpuBuffer(fontsList, directXState.structuredBuffers[.GLYPHS_LIST])
    directXState.ctx->DrawIndexedInstanced(directXState.indexBuffers[.QUAD].length, u32(glyphsCount), 0, 0, 0)
    //<
}