package main

import "core:fmt"

UiButton :: struct {
    text: string,
    position, size: int2,
    color, bgColor, hoverBgColor: float4,
}

renderButton :: proc(windowData: ^WindowData, button: UiButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc)
    position := button.position + getAbsolutePosition(windowData)

    uiRect := toRect(position, button.size)
    uiRectSize := getRectSize(uiRect)

    textWidth := getTextWidth(button.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0

    bgColor := button.bgColor

    if windowData.hotUiId == uiId { 
        bgColor = button.hoverBgColor.a != 0.0 ? button.hoverBgColor : getDarkerColor(bgColor) 
        
        if windowData.activeUiId == uiId { 
            bgColor = getDarkerColor(bgColor) 
        }
    }

    renderRect(windowData.directXState, uiRect, windowData.uiZIndex, bgColor)
    windowData.uiZIndex -= 0.1

    fontColor := button.color.a != 0.0 ? button.color : WHITE_COLOR

    renderLine(windowData.directXState, windowData, button.text, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        fontColor, windowData.uiZIndex)
    windowData.uiZIndex -= 0.1

    renderRectBorder(windowData.directXState, position, button.size, 1.0, windowData.uiZIndex, windowData.activeUiId == uiId ? DARKER_GRAY_COLOR : GRAY_COLOR)
    windowData.uiZIndex -= 0.1

    return checkUiState(windowData, uiId, uiRect)
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
    boxSize := int2{ 17, 17 }
    boxPosition := int2{ position.x, position.y + (i32(textHeight) - boxSize.y) / 2 }

    uiRect := toRect(position, { i32(textWidth) + boxSize.x + boxToTextPadding, i32(textHeight) })
    uiRectSize := getRectSize(uiRect)
    
    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0 + f32(boxToTextPadding)

    renderLine(windowData.directXState, windowData, checkbox.text, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        checkbox.color, windowData.uiZIndex)
    windowData.uiZIndex -= 0.1

    checkboxRect := toRect(boxPosition, boxSize)

    if checkbox.checked^ {
        renderRect(windowData.directXState, checkboxRect, windowData.uiZIndex, WHITE_COLOR)
        windowData.uiZIndex -= 0.1    
    }
    
    renderRectBorder(windowData.directXState, checkboxRect, 1.0, windowData.uiZIndex, windowData.activeUiId == uiId ? DARK_GRAY_COLOR : DARKER_GRAY_COLOR)
    windowData.uiZIndex -= 0.1
    
    if windowData.activeUiId == uiId {
        renderRectBorder(windowData.directXState, uiRect, 1.0, windowData.uiZIndex, LIGHT_GRAY_COLOR)
        windowData.uiZIndex -= 0.1           
    }

    action := checkUiState(windowData, uiId, uiRect)

    if .SUBMIT in action {
        checkbox.checked^ = !(checkbox.checked^)
    }

    return action
}

UiScroll :: struct {
    bgRect: Rect,
    offset: ^i32,
    height: i32,
    color, hoverColor, bgColor: float4,
}

renderVerticalScroll :: proc(windowData: ^WindowData, scroll: UiScroll, customId: i32 = 0, loc := #caller_location) -> UiActions {
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
    windowData.uiZIndex -= 0.1
    
    bgAction := checkUiState(windowData, bgUiId, bgRect)

    // scroll
    isHover := windowData.activeUiId == scrollUiId || windowData.hotUiId == scrollUiId
    renderRect(windowData.directXState, scrollRect, windowData.uiZIndex, isHover ? scroll.hoverColor : scroll.color)
    windowData.uiZIndex -= 0.1

    scrollAction := checkUiState(windowData, scrollUiId, scrollRect)

    if .ACTIVE in scrollAction {
        position, size := fromRect(scrollRect)

        mouseY := screenToDirectXCoords(windowData, windowData.mousePosition).y

        delta := windowData.deltaMousePosition.y

        if mouseY < bgRect.bottom {
            delta = abs(delta)
        } else if mouseY > bgRect.top {
            delta = -abs(delta)
        } 

        scroll.offset^ += delta

        scroll.offset^ = max(0, scroll.offset^)
        scroll.offset^ = min(bgRect.top - bgRect.bottom - scroll.height, scroll.offset^)
    }

    return scrollAction
}

UiPanel :: struct {
    title: string,
    position, size: ^int2,
    bgColor, hoverBgColor: float4,
}

beginPanel :: proc(windowData: ^WindowData, panel: UiPanel, customId: i32 = 0, loc := #caller_location) -> UiActions {
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
    windowData.uiZIndex -= 0.1

    // panel header
    headerBgColor := getDarkerColor(panel.bgColor)

    if windowData.hotUiId == headerUiId { headerBgColor = getDarkerColor(headerBgColor) }
    if windowData.activeUiId == headerUiId { headerBgColor = getDarkerColor(headerBgColor) }

    renderRect(windowData.directXState, headerRect, windowData.uiZIndex, headerBgColor)
    windowData.uiZIndex -= 0.1

    // panel title
    renderLine(windowData.directXState, windowData, panel.title, { panelRect.left, panelRect.top - textHeight }, 
        WHITE_COLOR, windowData.uiZIndex)
    windowData.uiZIndex -= 0.1

    renderRectBorder(windowData.directXState, panel.position^, panel.size^, 1.0, windowData.uiZIndex, GRAY_COLOR)
    windowData.uiZIndex -= 0.1

    panelAction := checkUiState(windowData, uiId, panelRect)
    headerAction := checkUiState(windowData, headerUiId, headerRect)

    if .ACTIVE in headerAction {
        panel.position.x += windowData.deltaMousePosition.x
        panel.position.y -= windowData.deltaMousePosition.y

        panelRect = toRect(panel.position^, panel.size^)

        panelRect = clipRect(windowRect, panelRect)
        position, size := fromRect(panelRect)

        panel.position^ = position
    }

    append(&windowData.parentPositionsStack, panel.position^)

    return panelAction
}

endPanel :: proc(windowData: ^WindowData) {
    pop(&windowData.parentPositionsStack)
}
