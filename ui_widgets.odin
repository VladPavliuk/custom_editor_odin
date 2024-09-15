package main

@(private="file")
UiButton :: struct {
    position, size: int2,
    bgColor, hoverBgColor: float4,
    noBorder: bool,
}

renderButton :: proc{renderTextButton, renderImageButton}

@(private="file")
renderButton_Base :: proc(windowData: ^WindowData, button: UiButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc)
    position := button.position + getAbsolutePosition(windowData)

    uiRect := toRect(position, button.size)

    bgColor := button.bgColor

    if windowData.hotUiId == uiId { 
        bgColor = button.hoverBgColor.a != 0.0 ? button.hoverBgColor : getDarkerColor(bgColor) 
        
        if windowData.activeUiId == uiId { 
            bgColor = getDarkerColor(bgColor) 
        }
    }

    renderRect(windowData.directXState, uiRect, windowData.uiZIndex, bgColor)
    advanceUiZIndex(windowData)

    if !button.noBorder {       
        renderRectBorder(windowData.directXState, position, button.size, 1.0, windowData.uiZIndex, windowData.activeUiId == uiId ? DARKER_GRAY_COLOR : GRAY_COLOR)
        advanceUiZIndex(windowData)
    }
    return checkUiState(windowData, uiId, uiRect)
}

UiTextButton :: struct {
    using base: UiButton,
    text: string,
    color: float4,
}

@(private="file")
renderTextButton :: proc(windowData: ^WindowData, button: UiTextButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    actions := renderButton_Base(windowData, button.base, customId, loc)

    position := button.position + getAbsolutePosition(windowData)

    uiRect := toRect(position, button.size)
    uiRectSize := getRectSize(uiRect)

    textWidth := getTextWidth(button.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0

    fontColor := button.color.a != 0.0 ? button.color : WHITE_COLOR

    renderLine(windowData.directXState, windowData, button.text, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        fontColor, windowData.uiZIndex)
    advanceUiZIndex(windowData)

    return actions
}

UiImageButton :: struct {
    using base: UiButton,
    texture: TextureType,
    texturePadding: i32,
} 

@(private="file")
renderImageButton :: proc(windowData: ^WindowData, button: UiImageButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    actions := renderButton_Base(windowData, button.base, customId, loc)

    position := button.position + getAbsolutePosition(windowData)

    uiRect := toRect(position, button.size)

    uiRect.bottom += button.texturePadding
    uiRect.top -= button.texturePadding
    uiRect.left += button.texturePadding
    uiRect.right -= button.texturePadding

    renderImageRect(windowData.directXState, uiRect, windowData.uiZIndex, button.texture, button.bgColor)
    advanceUiZIndex(windowData)

    return actions
}

UiCheckbox :: struct {
    text: string,
    checked: ^bool,
    position: int2,
    color, bgColor, hoverBgColor: float4,
}

renderCheckbox :: proc(windowData: ^WindowData, checkbox: UiCheckbox, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc) 
    position := checkbox.position + getAbsolutePosition(windowData)

    textWidth := getTextWidth(checkbox.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)
    
    boxToTextPadding: i32 = 10
    boxSize := int2{ 16, 16 }
    boxPosition := int2{ position.x, position.y + (i32(textHeight) - boxSize.y) / 2 }

    uiRect := toRect(position, { i32(textWidth) + boxSize.x + boxToTextPadding, i32(textHeight) })
    uiRectSize := getRectSize(uiRect)
    
    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0 + f32(boxToTextPadding)

    renderLine(windowData.directXState, windowData, checkbox.text, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        checkbox.color, windowData.uiZIndex)
    advanceUiZIndex(windowData)

    checkboxRect := toRect(boxPosition, boxSize)

    if checkbox.checked^ {
        renderRect(windowData.directXState, checkboxRect, windowData.uiZIndex, WHITE_COLOR)
        advanceUiZIndex(windowData)    
    }
    
    renderRectBorder(windowData.directXState, checkboxRect, 1.0, windowData.uiZIndex, windowData.activeUiId == uiId ? DARK_GRAY_COLOR : DARKER_GRAY_COLOR)
    advanceUiZIndex(windowData)
    
    if windowData.activeUiId == uiId {
        renderRectBorder(windowData.directXState, uiRect, 1.0, windowData.uiZIndex, LIGHT_GRAY_COLOR)
        advanceUiZIndex(windowData)           
    }

    action := checkUiState(windowData, uiId, uiRect)

    if .SUBMIT in action {
        checkbox.checked^ = !(checkbox.checked^)
    }

    return action
}

UiDropdown :: struct {
    position: int2,
    size: int2,
    bgColor: float4,
    items: []string,
    selectedItemIndex: ^i32,
    isOpen: ^bool,
    scrollOffset: ^i32,
    maxItemShow: i32,
}

renderDropdown :: proc(windowData: ^WindowData, dropdown: UiDropdown, customId: i32 = 0, loc := #caller_location) -> UiActions {
    assert(dropdown.selectedItemIndex != nil)
    assert(dropdown.isOpen != nil)
    itemsCount := i32(len(dropdown.items))
    assert(dropdown.selectedItemIndex^ >= 0 && dropdown.selectedItemIndex^ < itemsCount)
    assert(itemsCount > 0)
    assert(dropdown.maxItemShow > 0)
    customId := customId
    customId += 1
    scrollWidth: i32 = 10

    action := renderButton(windowData, UiTextButton{
        text = dropdown.items[dropdown.selectedItemIndex^],
        position = dropdown.position,
        size = dropdown.size,
        bgColor = dropdown.bgColor,
    }, customId, loc)

    if .SUBMIT in action {
        dropdown.isOpen^ = !(dropdown.isOpen^)
    }

    if dropdown.isOpen^ {
        itemHeight := i32(getTextHeight(&windowData.font))
        offset := dropdown.position.y - itemHeight

        scrollOffsetIndex: i32 = 0
        hasScrollBar := false
        scrollHeight: i32 = -1
        itemsToShow := min(dropdown.maxItemShow, itemsCount)
        itemsContainerHeight := itemsToShow * itemHeight
        
        // show scrollbar
        if itemsCount > dropdown.maxItemShow {
            hasScrollBar = true
            scrollHeight = i32(f32(dropdown.maxItemShow) / f32(itemsCount) * f32(itemsContainerHeight))

            beginScroll(windowData)

            scrollOffsetIndex = i32(f32(f32(dropdown.scrollOffset^) / f32(itemsContainerHeight - scrollHeight)) * f32(itemsCount - dropdown.maxItemShow))
        }
        
        itemWidth := dropdown.size.x

        if hasScrollBar { itemWidth -= scrollWidth } 

        // render list
        for i in 0..<itemsToShow {
            index := i + scrollOffsetIndex
            item := dropdown.items[index]
            customId += 1

            itemActions := renderButton(windowData, UiTextButton{
                position = { dropdown.position.x, offset },
                size = { itemWidth, itemHeight },
                text = item,
                bgColor = i32(index) == dropdown.selectedItemIndex^ ? getDarkerColor(dropdown.bgColor) : dropdown.bgColor,
            }, customId, loc)

            if .SUBMIT in itemActions {
                dropdown.selectedItemIndex^ = i32(index)
                dropdown.isOpen^ = false
            }

            offset -= itemHeight
        }

        if hasScrollBar {
            customId += 1

            endScroll(windowData, UiScroll{
                bgRect = Rect{
                    top = dropdown.position.y,
                    bottom = dropdown.position.y - itemsContainerHeight,
                    right = dropdown.position.x + dropdown.size.x,
                    left = dropdown.position.x + dropdown.size.x - scrollWidth,
                },
                offset = dropdown.scrollOffset,
                height = scrollHeight,
                color = WHITE_COLOR,
                hoverColor = LIGHT_GRAY_COLOR,
                bgColor = BLACK_COLOR,
            }, customId, loc)
        }
    }

    return action
}

UiScroll :: struct {
    bgRect: Rect,
    offset: ^i32,
    height: i32,
    color, hoverColor, bgColor: float4,
}

beginScroll :: proc(windowData: ^WindowData) {
    append(&windowData.scrollableElements, make(map[uiId]struct{}))
}

endScroll :: proc(windowData: ^WindowData, scroll: UiScroll, customId: i32 = 0, loc := #caller_location) -> UiActions {
    assert(scroll.offset != nil)
    scrollableElements := pop(&windowData.scrollableElements)
    defer delete(scrollableElements)

    scrollUiId := getUiId(customId, loc)
    
    bgUiId := getUiId((customId + 1) * 99999999, loc)

    position, size := fromRect(scroll.bgRect)
    position += getAbsolutePosition(windowData)

    bgRect := toRect(position, size)

    scrollRect := Rect{
        top = bgRect.top - scroll.offset^,
        bottom = bgRect.top - scroll.offset^ - scroll.height,
        left = bgRect.left,
        right = bgRect.right,
    }

    // background
    renderRect(windowData.directXState, bgRect, windowData.uiZIndex, scroll.bgColor)
    advanceUiZIndex(windowData)
    
    bgAction := checkUiState(windowData, bgUiId, bgRect)

    // scroll
    isHover := windowData.activeUiId == scrollUiId || windowData.hotUiId == scrollUiId
    renderRect(windowData.directXState, scrollRect, windowData.uiZIndex, isHover ? scroll.hoverColor : scroll.color)
    advanceUiZIndex(windowData)

    scrollAction := checkUiState(windowData, scrollUiId, scrollRect)

    validateScrollOffset :: proc(offset: ^i32, maxOffset: i32) {
        offset^ = max(0, offset^)
        offset^ = min(maxOffset, offset^)
    }

    if .ACTIVE in scrollAction {
        mouseY := screenToDirectXCoords(windowData, windowData.mousePosition).y

        delta := windowData.deltaMousePosition.y

        if mouseY < bgRect.bottom {
            delta = abs(delta)
        } else if mouseY > bgRect.top {
            delta = -abs(delta)
        }

        scroll.offset^ += delta

        validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.height)
    }

    if windowData.hotUiId in scrollableElements || .MOUSE_WHEEL_SCROLL in bgAction || .MOUSE_WHEEL_SCROLL in scrollAction {
        scroll.offset^ -= windowData.scrollDelta
        validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.height)
    }

    return scrollAction
}

UiPanel :: struct {
    title: string,
    position, size: ^int2,
    bgColor, hoverBgColor: float4,
}

beginPanel :: proc(windowData: ^WindowData, panel: UiPanel, open: ^bool, customId: i32 = 0, loc := #caller_location) -> UiActions {
    customId := customId
    uiId := getUiId(customId, loc)
    headerUiId := getUiId((customId + 1) * 999999, loc)
    
    panelRect := toRect(panel.position^, panel.size^)

    textHeight := i32(getTextHeight(&windowData.font))

    headerRect := Rect{ 
        top = panelRect.top,  
        bottom = panelRect.top - textHeight,
        left = panelRect.left,
        right = panelRect.right,
    }

    //> make sure that panel is on the screen
    windowRect := Rect{
        top = windowData.size.y / 2,
        bottom = -windowData.size.y / 2,
        right = windowData.size.x / 2,
        left = -windowData.size.x / 2,
    }

    panelRect = clipRect(windowRect, panelRect)    
    panel.position^, _ = fromRect(panelRect)
    //<

    // panel body
    renderRect(windowData.directXState, panelRect, windowData.uiZIndex, panel.bgColor)
    advanceUiZIndex(windowData)

    // panel header
    headerBgColor := getDarkerColor(panel.bgColor)

    if windowData.hotUiId == headerUiId { headerBgColor = getDarkerColor(headerBgColor) }
    if windowData.activeUiId == headerUiId { headerBgColor = getDarkerColor(headerBgColor) }

    renderRect(windowData.directXState, headerRect, windowData.uiZIndex, headerBgColor)
    advanceUiZIndex(windowData)

    // panel title
    renderLine(windowData.directXState, windowData, panel.title, { panelRect.left, panelRect.top - textHeight }, 
        WHITE_COLOR, windowData.uiZIndex)
    advanceUiZIndex(windowData)

    panelAction := checkUiState(windowData, uiId, panelRect)
    headerAction := checkUiState(windowData, headerUiId, headerRect)

    // panel close button
    customId += 1
    closeButtonSize := headerRect.top - headerRect.bottom
    if .SUBMIT in renderButton(windowData, UiImageButton{
        position = { headerRect.right - closeButtonSize, headerRect.bottom },
        size = { closeButtonSize, closeButtonSize },
        bgColor = headerBgColor,
        texture = .CLOSE_ICON,
        texturePadding = 2,
        noBorder = true,
    }, customId, loc) {
        open^ = false
    }

    renderRectBorder(windowData.directXState, panel.position^, panel.size^, 1.0, windowData.uiZIndex, GRAY_COLOR)
    advanceUiZIndex(windowData)

    if .ACTIVE in headerAction {
        panel.position.x += windowData.deltaMousePosition.x
        panel.position.y -= windowData.deltaMousePosition.y

        panelRect = toRect(panel.position^, panel.size^)

        panelRect = clipRect(windowRect, panelRect)
        position, _ := fromRect(panelRect)

        panel.position^ = position
    }

    append(&windowData.parentPositionsStack, panel.position^)

    return panelAction
}

endPanel :: proc(windowData: ^WindowData) {
    pop(&windowData.parentPositionsStack)
}
