package main

import "core:fmt"

UiButton :: struct {
    text: string,
    position, size: int2,
    color, bgColor, hoverBgColor: float4,
}

renderButton :: proc(windowData: ^WindowData, button: UiButton, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc)

    uiRect := toRect(button.position, button.size)
    uiRectSize := getRectSize(uiRect)

    textWidth := getTextWidth(button.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0

    showHoverColor := windowData.activeUiId == uiId || windowData.hotUiId == uiId
    renderRect(windowData.directXState, uiRect, windowData.uiZIndex, showHoverColor ? button.hoverBgColor : button.bgColor)
    windowData.uiZIndex -= 0.1

    renderLine(windowData.directXState, windowData, button.text, { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom }, 
        button.color, windowData.uiZIndex)
    windowData.uiZIndex -= 0.1

    return checkUiState(windowData, uiId, uiRect)
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
    
    scrollRect := Rect{
        top = scroll.bgRect.top - scroll.offset^,
        bottom = scroll.bgRect.top - scroll.offset^ - scroll.height,
        left = scroll.bgRect.left,
        right = scroll.bgRect.right,
    }

    // background
    renderRect(windowData.directXState, scroll.bgRect, windowData.uiZIndex, scroll.bgColor)
    windowData.uiZIndex -= 0.1
    
    bgAction := checkUiState(windowData, bgUiId, scroll.bgRect)

    // scroll
    isHover := windowData.activeUiId == scrollUiId || windowData.hotUiId == scrollUiId
    renderRect(windowData.directXState, scrollRect, windowData.uiZIndex, isHover ? scroll.hoverColor : scroll.color)
    windowData.uiZIndex -= 0.1

    scrollAction := checkUiState(windowData, scrollUiId, scrollRect)

    if .ACTIVE in scrollAction {
        position, size := fromRect(scrollRect)

        mouseY := screenToDirectXCoords(windowData, windowData.mousePosition).y

        delta := windowData.deltaMousePosition.y

        if mouseY < scroll.bgRect.bottom {
            delta = abs(delta)
        } else if mouseY > scroll.bgRect.top {
            delta = -abs(delta)
        } 

        scroll.offset^ += delta

        scroll.offset^ = max(0, scroll.offset^)
        scroll.offset^ = min(scroll.bgRect.top - scroll.bgRect.bottom - scroll.height, scroll.offset^)
    }

    return scrollAction
}

UiPanel :: struct {
    title: string,
    position, size: ^int2,
    bgColor, hoverBgColor: float4,
}

renderPanel :: proc(windowData: ^WindowData, panel: UiPanel, customId: i32 = 0, loc := #caller_location) -> UiActions {
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
    position, size := fromRect(panelRect)
    panel.position^ = position
    //<

    // panel body
    renderRect(windowData.directXState, panelRect, windowData.uiZIndex, panel.bgColor)
    windowData.uiZIndex -= 0.1

    // panel header
    showHoverColor := windowData.activeUiId == headerUiId || windowData.hotUiId == headerUiId
    renderRect(windowData.directXState, headerRect, windowData.uiZIndex, showHoverColor ? panel.hoverBgColor : panel.bgColor)
    windowData.uiZIndex -= 0.1

    // panel title
    renderLine(windowData.directXState, windowData, panel.title, { panelRect.left, panelRect.top - textHeight }, 
        WHITE_COLOR, windowData.uiZIndex)
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

    return panelAction
}
