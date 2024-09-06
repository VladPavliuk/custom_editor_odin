package main

import "core:fmt"

import "base:runtime"

uiId :: runtime.Source_Code_Location

UiActions :: bit_set[UiAction; u32]

UiAction :: enum u32 {
    SUBMIT,
    HOT,
    ACTIVE,
    GOT_ACTIVE,
    LOST_ACTIVE,
    MOUSE_ENTER,
    MOUSE_LEAVE,
}

UiButton :: struct {
    text: string,
    position, size: int2,
    color, bgColor, hoverBgColor: float4,
}

UiPanel :: struct {
    title: string,
    position, size: int2,
    bgColor, hoverBgColor: float4,
}

beginUi :: proc(windowData: ^WindowData) {
    windowData.uiZIndex = windowData.maxZIndex / 2.0
    windowData.tmpHotUiId = {}
    clear(&windowData.renderedUiIds)
}

endUi :: proc(windowData: ^WindowData) {
    windowData.hotUiIdChanged = false
    if windowData.tmpHotUiId != windowData.hotUiId {
        windowData.prevHotUiId = windowData.hotUiId
        windowData.hotUiIdChanged = true
    }

    windowData.hotUiId = windowData.tmpHotUiId

    //? Remove cached ui rects that where not drawn in the frame
    cachedUiRectsToDelete := make([dynamic]uiId)
    defer delete(cachedUiRectsToDelete)

    for cachedUiId, cachedUiRect in windowData.cachedUiRects {
        hasCachedUiId := false
        for uiId in windowData.renderedUiIds {
            if cachedUiId == uiId {
                hasCachedUiId = true
                break
            }
        }

        if !hasCachedUiId { 
            append(&cachedUiRectsToDelete, cachedUiId) 
        }
    }

    for cachedUiId in cachedUiRectsToDelete { delete_key(&windowData.cachedUiRects, cachedUiId) }
    //<
}

putUiRectToCache :: proc(windowData: ^WindowData, uiId: uiId, rect: Rect) -> Rect {
    if !(uiId in windowData.cachedUiRects) {
        windowData.cachedUiRects[uiId] = rect
    }

    return windowData.cachedUiRects[uiId]
}

renderButton :: proc(windowData: ^WindowData, button: UiButton, loc := #caller_location) -> UiActions {
    uiId := loc

    uiRect := putUiRectToCache(windowData, uiId, toRect(button.position, button.size))
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

    append(&windowData.renderedUiIds, uiId)
    return checkUiState(windowData, uiId, uiRect)
}

renderPanel :: proc(windowData: ^WindowData, panel: UiPanel, loc := #caller_location) -> UiActions {
    uiId := loc
    
    uiRect := putUiRectToCache(windowData, uiId, toRect(panel.position, panel.size))
    uiRectSize := getRectSize(uiRect)

    //> make sure that panel is on the screen
    windowRect := Rect{
        top = windowData.size.y / 2,
        bottom = -windowData.size.y / 2,
        right = windowData.size.x / 2,
        left = -windowData.size.x / 2,
    }

    uiRect = clipRect(windowRect, uiRect)
    windowData.cachedUiRects[uiId] = uiRect
    //<

    // panel body
    renderRect(windowData.directXState, uiRect, windowData.uiZIndex, panel.bgColor)
    windowData.uiZIndex -= 0.1

    // panel header
    textHeight := i32(getTextHeight(&windowData.font))
    showHoverColor := windowData.activeUiId == uiId || windowData.hotUiId == uiId
    headerRect := Rect{ 
        top = uiRect.top,  
        bottom = uiRect.top - textHeight,
        left = uiRect.left,
        right = uiRect.right,
    }
    renderRect(windowData.directXState, headerRect, windowData.uiZIndex, showHoverColor ? panel.hoverBgColor : panel.bgColor)
    windowData.uiZIndex -= 0.1

    // panel title
    renderLine(windowData.directXState, windowData, panel.title, { uiRect.left, uiRect.top - textHeight }, 
        WHITE_COLOR, windowData.uiZIndex)
    windowData.uiZIndex -= 0.1

    append(&windowData.renderedUiIds, uiId)
    uiAction := checkUiState(windowData, uiId, headerRect)

    if .ACTIVE in uiAction {
        uiRect.left += windowData.deltaMousePosition.x
        uiRect.right += windowData.deltaMousePosition.x
        uiRect.bottom -= windowData.deltaMousePosition.y
        uiRect.top -= windowData.deltaMousePosition.y

        uiRect = clipRect(windowRect, uiRect)

        windowData.cachedUiRects[uiId] = uiRect
    }

    return uiAction
}

renderVerticalScrollBar :: proc(windowData: ^WindowData, loc := #caller_location) -> UiActions {
    maxLinesOnScreen := getEditorSize(windowData).y / i32(windowData.font.lineHeight)
    totalLines := i32(len(windowData.screenGlyphs.lines))
    uiId := loc

    if totalLines == 1 { return {} }

    // draw background
    scrollWidth := windowData.editorPadding.right
    renderRect(windowData.directXState, float2{ f32(windowData.size.x) / 2.0 - f32(scrollWidth), -f32(windowData.size.y) / 2.0 }, 
        float2{ f32(scrollWidth), f32(windowData.size.y) }, windowData.uiZIndex, float4{ 0.2, 0.2, 0.2, 1.0 })
    windowData.uiZIndex -= 0.1

    scrollHeight := i32(f32(windowData.size.y * maxLinesOnScreen) / f32(maxLinesOnScreen + (totalLines - 1)))

    // NOTE: disable automatic top offset calculation if vertical scroll is selected by user 
    if windowData.activeUiId != uiId {
        windowData.verticalScrollTopOffset = i32(f32(windowData.screenGlyphs.lineIndex) / f32(maxLinesOnScreen + totalLines) * f32(windowData.size.y))
    }

    // draw scroll
    position := int2{ windowData.size.x / 2 - scrollWidth, windowData.size.y / 2 - windowData.verticalScrollTopOffset - scrollHeight }

    color := float4{ 0.7, 0.7, 0.7, 1.0 }
    hoverColor := float4{ 1.0, 1.0, 1.0, 1.0 }
    isHovered := windowData.hotUiId == uiId || windowData.activeUiId == uiId

    renderRect(windowData.directXState, 
        position,
        int2{ scrollWidth, scrollHeight }, windowData.uiZIndex, isHovered ? hoverColor : color)
    windowData.uiZIndex -= 0.1

    append(&windowData.renderedUiIds, uiId)
    return checkUiState(windowData, uiId, toRect(position, int2{ scrollWidth, scrollHeight }))
}

checkUiState :: proc(windowData: ^WindowData, uiId: uiId, rect: Rect) -> UiActions{
    mousePosition := screenToDirectXCoords(windowData, { i32(windowData.mousePosition.x), i32(windowData.mousePosition.y) })

    action: UiActions = nil
    
    if windowData.activeUiId == uiId {
        if windowData.wasLeftMouseButtonUp {
            if windowData.hotUiId == uiId {
                action += {.SUBMIT}
            }

            action += {.LOST_ACTIVE}
            windowData.activeUiId = {}
        } else {
            action += {.ACTIVE}
        }
    } else if windowData.hotUiId == uiId {
        if windowData.wasLeftMouseButtonDown {
            windowData.activeUiId = uiId
            action += {.GOT_ACTIVE}
        }
    }
    
    if windowData.hotUiIdChanged && windowData.hotUiId == uiId {
        action += {.MOUSE_ENTER}
    } else if windowData.hotUiIdChanged && windowData.prevHotUiId == uiId {
        action += {.MOUSE_LEAVE}
    } 
    
    if windowData.hotUiId == uiId {
        action += {.HOT}
    }

    if isInRect(rect, mousePosition) {
        windowData.tmpHotUiId = uiId
    }

    return action
}

clipRect :: proc(target, source: Rect) -> Rect {
    targetSize := getRectSize(target)
    sourceSize := getRectSize(source)

    // if source panel size is bigger then target panel size, do nothing 
    if sourceSize.x > targetSize.x || sourceSize.y > targetSize.y {
        return source
    }

    source := source

    // right side
    source.right = min(source.right, target.right)
    source.left = source.right - sourceSize.x

    // left side
    source.left = max(source.left, target.left)
    source.right = source.left + sourceSize.x

    // top side
    source.top = min(source.top, target.top)
    source.bottom = source.top - sourceSize.y

    // bottom side
    source.bottom = max(source.bottom, target.bottom)
    source.top = source.bottom + sourceSize.y

    return source
}

screenToDirectXCoords :: proc(windowData: ^WindowData, coords: int2) -> int2 {
    return {
        coords.x - windowData.size.x / 2,
        -coords.y + windowData.size.y / 2,
    }
}

directXToScreenToCoords :: proc(windowData: ^WindowData, coords: int2) -> int2 {
    return {
        coords.x + windowData.size.x / 2,
        coords.y + windowData.size.x / 2,
    }
}
