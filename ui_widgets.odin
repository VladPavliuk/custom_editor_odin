package main

import "core:mem"

@(private="file")
UiButton :: struct {
    position, size: int2,
    bgColor, hoverBgColor: float4,
    noBorder: bool,
    ignoreFocusUpdate: bool,
    disabled: bool,
}

renderButton :: proc{renderTextButton, renderImageButton}

@(private="file")
renderButton_Base :: proc(ctx: ^UiContext, button: UiButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc)
    position := button.position + getAbsolutePosition(ctx)

    uiRect := toRect(position, button.size)

    bgColor: float4
    if !button.disabled {
        bgColor = button.bgColor

        if ctx.hotId == uiId { 
            bgColor = button.hoverBgColor.a != 0.0 ? button.hoverBgColor : getDarkerColor(bgColor) 
            
            if ctx.activeId == uiId { 
                bgColor = getDarkerColor(bgColor) 
            }
        }
    } else {
        bgColor = DARK_GRAY_COLOR
    }

    renderRect(uiRect, ctx.zIndex, bgColor)
    advanceUiZIndex(ctx)

    if !button.noBorder {       
        renderRectBorder(position, button.size, 1.0, ctx.zIndex, ctx.activeId == uiId ? DARKER_GRAY_COLOR : GRAY_COLOR)
        advanceUiZIndex(ctx)
    }

    return button.disabled ? {} : checkUiState(ctx, uiId, uiRect, button.ignoreFocusUpdate)
}

UiTextButton :: struct {
    using base: UiButton,
    text: string,
    color: float4,
}

@(private="file")
renderTextButton :: proc(ctx: ^UiContext, button: UiTextButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    actions := renderButton_Base(ctx, button.base, customId, loc)

    position := button.position + getAbsolutePosition(ctx)

    uiRect := toRect(position, button.size)
    uiRectSize := getRectSize(uiRect)

    textWidth := getTextWidth(button.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0

    fontColor := button.color.a != 0.0 ? button.color : WHITE_COLOR

    setClipRect(uiRect)
    renderLine(button.text, &windowData.font, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        fontColor, ctx.zIndex)
    advanceUiZIndex(ctx)
    resetClipRect()

    return actions
}

UiImageButton :: struct {
    using base: UiButton,
    texture: TextureType,
    texturePadding: i32,
} 

@(private="file")
renderImageButton :: proc(ctx: ^UiContext, button: UiImageButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    actions := renderButton_Base(ctx, button.base, customId, loc)

    position := button.position + getAbsolutePosition(ctx)

    uiRect := toRect(position, button.size)

    uiRect.bottom += button.texturePadding
    uiRect.top -= button.texturePadding
    uiRect.left += button.texturePadding
    uiRect.right -= button.texturePadding

    renderImageRect(uiRect, ctx.zIndex, button.texture)
    advanceUiZIndex(ctx)

    return actions
}

UiLabel :: struct {
    text: string,
    position: int2,
    color: float4,
}

renderLabel :: proc(ctx: ^UiContext, label: UiLabel, customId: i32 = 0, loc := #caller_location) -> UiActions {
    position := label.position + getAbsolutePosition(ctx)
    actions := UiActions{}

    renderLine(label.text, &windowData.font, position, label.color, ctx.zIndex)
    advanceUiZIndex(ctx)

    return actions
}

UiTextField :: struct {
    text: string,
    position, size: int2,
    bgColor: float4,
}

renderTextField :: proc(ctx: ^UiContext, textField: UiTextField, customId: i32 = 0, loc := #caller_location) -> UiActions {    
    uiId := getUiId(customId, loc)
    position := textField.position + getAbsolutePosition(ctx)

    uiRect := toRect(position, textField.size)

    bgColor := WHITE_COLOR

    if ctx.hotId == uiId { 
        bgColor = getDarkerColor(bgColor) 
        
        if ctx.activeId == uiId { 
            bgColor = getDarkerColor(bgColor) 
        }
    }

    renderRect(uiRect, ctx.zIndex, bgColor)
    advanceUiZIndex(ctx)

    hasFocus := ctx.focusedId == uiId || ctx.hotId == uiId
    renderRectBorder(uiRect, hasFocus ? 2 : 1, ctx.zIndex, BLACK_COLOR)
    advanceUiZIndex(ctx)

    textHeight := getTextHeight(&windowData.font)
    
    actions := checkUiState(ctx, uiId, uiRect)

    if .GOT_FOCUS in actions {
        switchInputContextToUiElement(Rect {
            top = uiRect.top - textField.size.y / 2 + i32(textHeight / 2),
            bottom = uiRect.bottom + textField.size.y / 2 - i32(textHeight / 2),
            left = uiRect.left + 5,
            right = uiRect.right - 5,
        }, true)
    } 

    if .LOST_FOCUS in actions {
        switchInputContextToEditor()
    }

    if ctx.focusedId == uiId {
        calculateLines(&ctx.textInputCtx)
        updateCusrorData(&ctx.textInputCtx)
    
        handleTextInputActions(&ctx.textInputCtx, actions)

        setClipRect(uiRect)
        glyphsCount, selectionsCount := fillTextBuffer(&ctx.textInputCtx, ctx.zIndex)

        renderText(glyphsCount, selectionsCount, BLACK_COLOR, TEXT_SELECTION_BG_COLOR)
        resetClipRect()
    } else {
        setClipRect(uiRect)
        renderLine(textField.text, &windowData.font, { uiRect.left + 5, uiRect.bottom + textField.size.y / 2 - i32(textHeight / 2) }, 
            BLACK_COLOR, ctx.zIndex)
        advanceUiZIndex(ctx)
        resetClipRect()
    }

    return actions
}

handleTextInputActions :: proc(ctx: ^EditableTextContext, actions: UiActions) {
    if .GOT_ACTIVE in actions {
        pos := getCursorIndexByMousePosition(ctx)
        ctx.editorState.selection = { pos, pos }
    }

    if .ACTIVE in actions {
        ctx.editorState.selection[0] = getCursorIndexByMousePosition(ctx)
    }   
}

UiCheckbox :: struct {
    text: string,
    checked: ^bool,
    position: int2,
    color, bgColor, hoverBgColor: float4,
}

renderCheckbox :: proc(ctx: ^UiContext, checkbox: UiCheckbox, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc)
    position := checkbox.position + getAbsolutePosition(ctx)

    textWidth := getTextWidth(checkbox.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)
    
    boxToTextPadding: i32 = 10
    boxSize := int2{ 16, 16 }
    boxPosition := int2{ position.x, position.y + (i32(textHeight) - boxSize.y) / 2 }

    uiRect := toRect(position, { i32(textWidth) + boxSize.x + boxToTextPadding, i32(textHeight) })
    uiRectSize := getRectSize(uiRect)
    
    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0 + f32(boxToTextPadding)

    renderLine(checkbox.text, &windowData.font, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        checkbox.color, ctx.zIndex)
    advanceUiZIndex(ctx)

    checkboxRect := toRect(boxPosition, boxSize)

    if checkbox.checked^ {
        renderRect(checkboxRect, ctx.zIndex, WHITE_COLOR)
        advanceUiZIndex(ctx)    
    }
    
    renderRectBorder(checkboxRect, 1.0, ctx.zIndex, ctx.activeId == uiId ? DARK_GRAY_COLOR : DARKER_GRAY_COLOR)
    advanceUiZIndex(ctx)
    
    if ctx.activeId == uiId {
        renderRectBorder(uiRect, 1.0, ctx.zIndex, LIGHT_GRAY_COLOR)
        advanceUiZIndex(ctx)           
    }

    action := checkUiState(ctx, uiId, uiRect)

    if .SUBMIT in action {
        checkbox.checked^ = !(checkbox.checked^)
    }

    return action
}

UiDropdownItem :: struct {
    text: string,
    rightText: string, // optional
    checkbox: ^bool, // if nil, don't show it
    isSeparator: bool,
    //TODO: add context menu item
}

UiDropdownItemStyle :: struct {
    size: int2,
    padding: Rect,
    bgColor, hoverColor, activeColor: float4,
}

UiDropdown :: struct {
    text: string,
    position: int2,
    size: int2,
    bgColor: float4,
    items: []UiDropdownItem, // TODO: maybe union{[]UiDropdownItem, []string}, ???
    selectedItemIndex: i32,
    isOpen: ^bool,
    scrollOffset: ^i32,
    maxItemShow: i32,
    itemStyles: UiDropdownItemStyle,
}

renderDropdown :: proc(ctx: ^UiContext, dropdown: UiDropdown, customId: i32 = 0, loc := #caller_location) -> (UiActions, i32) {
    assert(dropdown.isOpen != nil)
    itemsCount := i32(len(dropdown.items))
    assert(dropdown.selectedItemIndex >= -1 && dropdown.selectedItemIndex < itemsCount)
    assert(itemsCount > 0)
    assert(dropdown.maxItemShow > 0)
    customId := customId
    customId += 1
    scrollWidth: i32 = 10
    selectedItemIndex := dropdown.selectedItemIndex
    actions: UiActions = {}

    text: string
    if len(dropdown.text) > 0 { text = dropdown.text }
    else {
        assert(dropdown.selectedItemIndex >= 0)
        text = dropdown.items[dropdown.selectedItemIndex].text
    }

    buttonActions := renderButton(ctx, UiTextButton{
        text = text,
        position = dropdown.position,
        size = dropdown.size,
        bgColor = dropdown.bgColor,
        noBorder = true,
    }, customId, loc)

    if .SUBMIT in buttonActions {
        dropdown.isOpen^ = !(dropdown.isOpen^)
    }

    if .LOST_FOCUS in buttonActions {
        dropdown.isOpen^ = false
    }

    if dropdown.isOpen^ {
        itemPadding := dropdown.itemStyles.padding
        itemHeight := i32(getTextHeight(&windowData.font)) + itemPadding.bottom + itemPadding.top
        offset := dropdown.position.y - itemHeight

        scrollOffsetIndex: i32 = 0
        hasScrollBar := false
        scrollHeight: i32 = -1
        itemsToShow := min(dropdown.maxItemShow, itemsCount)
        itemsContainerHeight := itemsToShow * itemHeight
        itemsContainerWidth := dropdown.itemStyles.size.x > 0 ? dropdown.itemStyles.size.x : dropdown.size.x
        
        // show scrollbar
        if itemsCount > dropdown.maxItemShow {
            hasScrollBar = true
            scrollHeight = i32(f32(dropdown.maxItemShow) / f32(itemsCount) * f32(itemsContainerHeight))

            beginScroll(ctx)

            scrollOffsetIndex = i32(f32(f32(dropdown.scrollOffset^) / f32(itemsContainerHeight - scrollHeight)) * f32(itemsCount - dropdown.maxItemShow))
        }
        
        itemWidth := itemsContainerWidth

        if hasScrollBar { itemWidth -= scrollWidth } 

        // render list
        for i in 0..<itemsToShow {
            index := i + scrollOffsetIndex
            item := dropdown.items[index]
            customId += 1

            defer offset -= itemHeight

            itemRect := toRect({ dropdown.position.x, offset }, { itemWidth, itemHeight })

            bgColor := getOrDefaultColor(dropdown.itemStyles.bgColor, dropdown.bgColor)

            if item.isSeparator {
                putEmptyUiElement(ctx, itemRect, true, customId, loc) // just to prevent closing dropdown on seperator click

                renderRect(itemRect, ctx.zIndex, bgColor)
                advanceUiZIndex(ctx)

                separatorHorizontalPadding: i32 = 10
                renderRect(int2{ dropdown.position.x + separatorHorizontalPadding, offset + itemHeight / 2 }, 
                    int2{ itemWidth - 2 * separatorHorizontalPadding, 1 }, ctx.zIndex, WHITE_COLOR)
                advanceUiZIndex(ctx)
                continue
            }

            itemActions := putEmptyUiElement(ctx, itemRect, true, customId, loc)

            if .HOT in itemActions { bgColor = getOrDefaultColor(dropdown.itemStyles.hoverColor, getDarkerColor(bgColor)) }
            if .ACTIVE in itemActions { bgColor = getOrDefaultColor(dropdown.itemStyles.activeColor, getDarkerColor(bgColor)) } 

            setClipRect(itemRect)
            renderRect(itemRect, ctx.zIndex, bgColor)
            advanceUiZIndex(ctx)

            renderLine(item.text, &windowData.font, { dropdown.position.x + itemPadding.left, offset + itemPadding.bottom }, WHITE_COLOR, ctx.zIndex)
            advanceUiZIndex(ctx)

            // optional checkbox
            if item.checkbox != nil {
                checkboxSize := itemHeight

                checkboxPosition: int2 = { dropdown.position.x, offset }
                checkboxRect := toRect(checkboxPosition, { checkboxSize, checkboxSize })
                if item.checkbox^ {
                    renderImageRect(shrinkRect(checkboxRect, 3), ctx.zIndex, TextureType.CHECK_ICON)
                    advanceUiZIndex(ctx)
                }
                
                renderRectBorder(checkboxRect, 2.0, ctx.zIndex, DARK_GRAY_COLOR) 
                advanceUiZIndex(ctx)

                if .SUBMIT in putEmptyUiElement(ctx, checkboxRect, true) {
                    item.checkbox^ = !item.checkbox^
                }
            }

            if len(item.rightText) > 0 {
                rightTextPositionX := dropdown.position.x + itemWidth - i32(getTextWidth(item.rightText, &windowData.font)) - itemPadding.right
                renderLine(item.rightText, &windowData.font, { rightTextPositionX, offset + itemPadding.bottom }, WHITE_COLOR, ctx.zIndex)
                advanceUiZIndex(ctx)
            }
            resetClipRect()

            if .SUBMIT in itemActions {
                selectedItemIndex = i32(index)
                actions += {.SUBMIT}
                dropdown.isOpen^ = false

                if checkbox := dropdown.items[selectedItemIndex].checkbox; checkbox != nil {
                    checkbox^ = !checkbox^
                }
            }
        }

        if hasScrollBar {
            customId += 1

            endScroll(ctx, UiScroll{
                bgRect = Rect{
                    top = dropdown.position.y,
                    bottom = dropdown.position.y - itemsContainerHeight,
                    right = dropdown.position.x + itemsContainerWidth,
                    left = dropdown.position.x + itemsContainerWidth - scrollWidth,
                },
                offset = dropdown.scrollOffset,
                size = scrollHeight,
                color = WHITE_COLOR,
                hoverColor = LIGHT_GRAY_COLOR,
                bgColor = BLACK_COLOR,
            }, customId = customId, loc = loc)
        }
    }

    return actions, selectedItemIndex
}

UiAlert :: struct {
    text: string,
    timeout: f64,
    color, bgColor, hoverColor: float4,
    originalTimeout: f64, // don't specify it!
}

pushAlert :: proc(ctx: ^UiContext, alert: UiAlert, customId: i32 = 0, loc := #caller_location) {
    clearAlert(ctx)
    ctx.activeAlert = new(UiAlert)

    alert := alert
    alert.timeout = alert.timeout > 0.01 ? alert.timeout : 3.0
    alert.originalTimeout = alert.timeout
    mem.copy(ctx.activeAlert, &alert, size_of(UiAlert))
}

clearAlert :: proc(ctx: ^UiContext) {
    if ctx.activeAlert != nil {
        free(ctx.activeAlert)
        ctx.activeAlert = nil
    }
}

updateAlertTimeout :: proc(ctx: ^UiContext, delta: f64) {
    if ctx.activeAlert == nil { return }

    ctx.activeAlert.timeout -= delta

    if ctx.activeAlert.timeout < 0.0 {
        clearAlert(ctx)
    }
}

renderActiveAlert :: proc(ctx: ^UiContext, customId: i32 = 0, loc := #caller_location) -> UiActions {
    if ctx.activeAlert == nil { return {} }

    alert := ctx.activeAlert

    fadeOutDuration := 1.5
    fadeInDuration := 0.15

    customId := customId
    uiId := getUiId(customId, loc)

    textWidth := getTextWidth(alert.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)
    textPadding := int2{ 10, 5 }
    targetAlertOffset := int2{ 15, 5 }

    alertRect := Rect{
        top = -windowData.size.y / 2,
        bottom = -windowData.size.y / 2 - i32(textHeight) - 2 * textPadding.y,
        right = windowData.size.x / 2 - targetAlertOffset.x,
        left = windowData.size.x / 2 - i32(textWidth) - 2 * textPadding.x - targetAlertOffset.x,
    }

    alertRectSize := getRectSize(alertRect)

    //> fade-in animation
    verticalOffset := targetAlertOffset.y + alertRectSize.y

    if fadeInDuration > alert.originalTimeout - alert.timeout {
        delta := (alert.originalTimeout - alert.timeout) / fadeInDuration
        verticalOffset = i32(f64(verticalOffset) * delta)
    }

    alertRect.bottom += verticalOffset
    alertRect.top += verticalOffset
    //<

    closeButtonPadding: i32 = 5
    closeButtonSize := alertRect.top - alertRect.bottom - closeButtonPadding * 2
    alertRect.left -= closeButtonSize

    //> fade-out animation
    transparency: f32 = 1.0

    if alert.timeout < fadeOutDuration {
        transparency = f32(alert.timeout * 1.0 / fadeOutDuration)
    }
    //<

    bgColor := alert.bgColor
    bgColor.a = transparency 
    renderRect(alertRect, ctx.zIndex, bgColor)
    advanceUiZIndex(ctx)

    bottomTextPadding := (f32(alertRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(alertRectSize.x) - textWidth) / 2.0

    fontColor := alert.color.a != 0.0 ? alert.color : WHITE_COLOR

    fontColor.a = transparency 
    renderLine(alert.text, &windowData.font, { i32(leftTextPadding) + alertRect.left, i32(bottomTextPadding) + alertRect.bottom }, 
        fontColor, ctx.zIndex)
    advanceUiZIndex(ctx)

    alertActions := checkUiState(ctx, uiId, alertRect)

    // close button
    customId += 1
    closeBgColor := alert.bgColor
    closeBgColor.a = 0.0
    closeButtonActions := renderButton(ctx, UiImageButton{
        position = { alertRect.right - closeButtonSize - closeButtonPadding, alertRect.bottom + closeButtonPadding },
        size = { closeButtonSize, closeButtonSize },
        bgColor = closeBgColor,
        texture = .CLOSE_ICON,
        texturePadding = 2,
        noBorder = true,
    }, customId, loc) 

    if .SUBMIT in closeButtonActions {
        clearAlert(ctx)
    }

    if .HOT in alertActions || .HOT in closeButtonActions {
        alert.timeout = alert.originalTimeout - fadeInDuration
    }

    return alertActions
}

UiScroll :: struct {
    bgRect: Rect,
    
    offset: ^i32,
    size: i32,

    color, hoverColor, bgColor: float4,
}

beginScroll :: proc(ctx: ^UiContext) {
    append(&ctx.scrollableElements, make(map[uiId]struct{}))
}

endScroll :: proc(ctx: ^UiContext, verticalScroll: UiScroll, horizontalScroll: UiScroll = {}, customId: i32 = 0, loc := #caller_location) -> (UiActions, UiActions) {
    customId := customId
    verticalScrollActions := renderVerticalScroll(ctx, verticalScroll, customId, loc)
    horizontalScrollActions: UiActions = {}

    if horizontalScroll.offset != nil {
        customId += 1
        horizontalScrollActions = renderHorizontalScroll(ctx, horizontalScroll, customId, loc)
    }

    // if ctx.hotId in scrollableElements && abs(inputState.scrollDelta) > 0 {
    //     scrollAction += {.MOUSE_WHEEL_SCROLL}
    // }

    return verticalScrollActions, horizontalScrollActions
}

renderVerticalScroll :: proc(ctx: ^UiContext, scroll: UiScroll, customId: i32 = 0, loc := #caller_location) -> UiActions {
    assert(scroll.offset != nil)
    scrollableElements := pop(&ctx.scrollableElements)
    defer delete(scrollableElements)

    scrollUiId := getUiId(customId, loc)
    
    bgUiId := getUiId((customId + 1) * 99999999, loc)

    position, size := fromRect(scroll.bgRect)

    if size.y == scroll.size { return {} }

    position += getAbsolutePosition(ctx)

    bgRect := toRect(position, size)

    scrollRect := Rect{
        top = bgRect.top - scroll.offset^,
        bottom = bgRect.top - scroll.offset^ - scroll.size,
        left = bgRect.left,
        right = bgRect.right,
    }

    // background
    renderRect(bgRect, ctx.zIndex, scroll.bgColor)
    advanceUiZIndex(ctx)
    
    bgAction := checkUiState(ctx, bgUiId, bgRect, true)

    // scroll
    isHover := ctx.activeId == scrollUiId || ctx.hotId == scrollUiId
    renderRect(scrollRect, ctx.zIndex, isHover ? scroll.hoverColor : scroll.color)
    advanceUiZIndex(ctx)

    scrollAction := checkUiState(ctx, scrollUiId, scrollRect, true)

    validateScrollOffset :: proc(offset: ^i32, maxOffset: i32) {
        offset^ = max(0, offset^)
        offset^ = min(maxOffset, offset^)
    }

    if .ACTIVE in scrollAction {
        mouseY := screenToDirectXCoords(inputState.mousePosition).y

        delta := inputState.deltaMousePosition.y

        if mouseY < bgRect.bottom {
            delta = abs(delta)
        } else if mouseY > bgRect.top {
            delta = -abs(delta)
        }

        scroll.offset^ += delta

        validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.size)
    }

    if ctx.hotId in scrollableElements || .MOUSE_WHEEL_SCROLL in bgAction || .MOUSE_WHEEL_SCROLL in scrollAction {
        scroll.offset^ -= inputState.scrollDelta
        validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.size)
    }

    if ctx.hotId in scrollableElements && abs(inputState.scrollDelta) > 0 {
        scrollAction += {.MOUSE_WHEEL_SCROLL}
    }

    return scrollAction    
}

renderHorizontalScroll :: proc(ctx: ^UiContext, scroll: UiScroll, customId: i32 = 0, loc := #caller_location) -> UiActions {
    // assert(scroll.offset != nil)
    // scrollableElements := pop(&ctx.scrollableElements)
    // defer delete(scrollableElements)

    scrollUiId := getUiId(customId, loc)
    
    // bgUiId := getUiId((customId + 1) * 99999999, loc)

    position, size := fromRect(scroll.bgRect)

    if size.x == scroll.size { return {} }

    position += getAbsolutePosition(ctx)

    bgRect := toRect(position, size)

    scrollRect := Rect{
        top = bgRect.top,
        bottom = bgRect.bottom,
        left = bgRect.left + scroll.offset^,
        right = bgRect.left + scroll.offset^ + scroll.size,
    }

    // background
    renderRect(bgRect, ctx.zIndex, scroll.bgColor)
    advanceUiZIndex(ctx)
    
    //bgAction := checkUiState(ctx, bgUiId, bgRect, true)

    // scroll
    isHover := ctx.activeId == scrollUiId || ctx.hotId == scrollUiId
    renderRect(scrollRect, ctx.zIndex, isHover ? scroll.hoverColor : scroll.color)
    advanceUiZIndex(ctx)

    scrollAction := checkUiState(ctx, scrollUiId, scrollRect, true)

    validateScrollOffset :: proc(offset: ^i32, maxOffset: i32) {
        offset^ = max(0, offset^)
        offset^ = min(maxOffset, offset^)
    }

    if .ACTIVE in scrollAction {
        mouseX := screenToDirectXCoords(inputState.mousePosition).x

        delta := inputState.deltaMousePosition.x

        if mouseX < bgRect.left {
            delta = -abs(delta)
        } else if mouseX > bgRect.right {
            delta = abs(delta)
        }

        scroll.offset^ += delta

        validateScrollOffset(scroll.offset, bgRect.right - bgRect.left - scroll.size)
    }

    return scrollAction    
}

UiPanel :: struct {
    title: string,
    position, size: ^int2,
    bgColor, hoverBgColor: float4,
}

beginPanel :: proc(ctx: ^UiContext, panel: UiPanel, open: ^bool, customId: i32 = 0, loc := #caller_location) -> UiActions {
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
    renderRect(panelRect, ctx.zIndex, panel.bgColor)
    advanceUiZIndex(ctx)

    // panel header
    headerBgColor := getDarkerColor(panel.bgColor)

    if ctx.hotId == headerUiId { headerBgColor = getDarkerColor(headerBgColor) }
    if ctx.activeId == headerUiId { headerBgColor = getDarkerColor(headerBgColor) }

    renderRect(headerRect, ctx.zIndex, headerBgColor)
    advanceUiZIndex(ctx)

    // panel title
    renderLine(panel.title, &windowData.font, { panelRect.left, panelRect.top - textHeight }, 
        WHITE_COLOR, ctx.zIndex)
    advanceUiZIndex(ctx)

    panelAction := checkUiState(ctx, uiId, panelRect)
    headerAction := checkUiState(ctx, headerUiId, headerRect)

    // panel close button
    customId += 1
    closeButtonSize := headerRect.top - headerRect.bottom
    if .SUBMIT in renderButton(ctx, UiImageButton{
        position = { headerRect.right - closeButtonSize, headerRect.bottom },
        size = { closeButtonSize, closeButtonSize },
        bgColor = headerBgColor,
        texture = .CLOSE_ICON,
        texturePadding = 2,
        noBorder = true,
    }, customId, loc) {
        open^ = false
    }

    renderRectBorder(panel.position^, panel.size^, 1.0, ctx.zIndex, GRAY_COLOR)
    advanceUiZIndex(ctx)

    if .ACTIVE in headerAction {
        panel.position.x += inputState.deltaMousePosition.x
        panel.position.y -= inputState.deltaMousePosition.y

        panelRect = toRect(panel.position^, panel.size^)

        panelRect = clipRect(windowRect, panelRect)
        position, _ := fromRect(panelRect)

        panel.position^ = position
    }

    append(&ctx.parentPositionsStack, panel.position^)

    return panelAction
}

endPanel :: proc(ctx: ^UiContext) {
    pop(&ctx.parentPositionsStack)
}

UiTabsItem :: struct {
    text: string,
    icon: TextureType,
}

UiTabsItemStyles :: struct {
    size: int2,
    padding: Rect,
}

UiTabs :: struct {
    position: int2,
    activeTabIndex: ^i32,
    items: []UiTabsItem,
    itemStyles: UiTabsItemStyles,
    bgColor, hoverBgColor, activeColor: float4,
    hasClose: bool,
}

//TODO: move it higer, since it should be used for all ui staff
UiNoAction :: struct{}

UiTabsActionClose :: struct {
    closedTabIndex: i32,
}

UiTabsActions :: union{UiNoAction, UiTabsActionClose}

renderTabs :: proc(ctx: ^UiContext, tabs: UiTabs, customId: i32 = 0, loc := #caller_location) -> UiTabsActions {
    customId := customId
    tabsActions: UiTabsActions = UiNoAction{}

    leftOffset: i32 = 0
    for item, index in tabs.items {
        position: int2 = { tabs.position.x + leftOffset, tabs.position.y }
        padding := tabs.itemStyles.padding
        
        width := tabs.itemStyles.size.x
        if width == 0 { width = i32(getTextWidth(item.text, &windowData.font)) }
        
        height := tabs.itemStyles.size.y
        if height == 0 { height = i32(getTextHeight(&windowData.font)) }

        // size: int2 = { 
        //     width + padding.left + padding.right,
        //     height + padding.top + padding.bottom,
        // }
        itemRect := toRect(position, { width, height })

        itemActions := putEmptyUiElement(ctx, itemRect, customId = customId, loc = loc)

        bgColor := tabs.bgColor

        if tabs.activeTabIndex^ == i32(index) {
            bgColor = getDarkerColor(bgColor)
        } else {    
            if .HOT in itemActions { bgColor = getOrDefaultColor(tabs.hoverBgColor, getDarkerColor(bgColor)) }
            if .ACTIVE in itemActions { bgColor = getOrDefaultColor(tabs.activeColor, getDarkerColor(bgColor)) }
        }

        if .SUBMIT in itemActions { tabs.activeTabIndex^ = i32(index) }
        
        renderRect(itemRect, ctx.zIndex, bgColor)
        advanceUiZIndex(ctx)

        // icon
        iconSize: i32 = 0
        iconRightPadding: i32 = 0
        if item.icon != .NONE {
            iconSize = 10
            iconRightPadding = 5
            iconPosition: int2 = { position.x + padding.left, position.y + height / 2 - iconSize / 2 }
            
            renderImageRect(toRect(iconPosition, { iconSize, iconSize }), ctx.zIndex, item.icon)
            advanceUiZIndex(ctx)
        }

        textPosition: int2 = { position.x + padding.left + iconSize + iconRightPadding, position.y + padding.bottom }
        setClipRect(Rect { top = itemRect.top, bottom = itemRect.bottom, left = textPosition.x, right = itemRect.right - padding.right })
        renderLine(item.text, &windowData.font, textPosition, WHITE_COLOR, ctx.zIndex)
        advanceUiZIndex(ctx)
        resetClipRect()

        if tabs.hasClose {
            iconSize = 20
            iconRightPadding: i32 = 5
            iconPosition: int2 = { position.x + width - iconSize - iconRightPadding, position.y + height / 2 - iconSize / 2 }
            
            customId += 1
            if .SUBMIT in renderButton(ctx, UiImageButton{
                position = iconPosition,
                size = { iconSize, iconSize },
                texture = .CLOSE_ICON,
                texturePadding = 3,
                bgColor = bgColor,
                noBorder = true,
            }, customId, loc) {
                tabsActions = UiTabsActionClose{
                    closedTabIndex = i32(index)
                }
            }
        }

        customId += 1
        leftOffset += width
    }

    return tabsActions
}