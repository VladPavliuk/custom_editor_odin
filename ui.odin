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

beginUi :: proc(windowData: ^WindowData) {
    windowData.uiZIndex = windowData.maxZIndex / 2.0
    windowData.tmpHotUiId = {}
}

endUi :: proc(windowData: ^WindowData) {
    windowData.hotUiIdChanged = false
    if windowData.tmpHotUiId != windowData.hotUiId {
        windowData.prevHotUiId = windowData.hotUiId
        windowData.hotUiIdChanged = true
    }

    windowData.hotUiId = windowData.tmpHotUiId
}

renderButton :: proc(windowData: ^WindowData, button: UiButton, loc := #caller_location) -> UiActions {
    uiId := loc
    
    textWidth := getTextWidth(button.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    bottomTextPadding := (f32(button.size.y) - textHeight) / 2.0
    leftTextPadding := (f32(button.size.x) - textWidth) / 2.0

    showHoverColor := windowData.activeUiId == uiId || windowData.hotUiId == uiId
    renderRect(windowData.directXState, button.position, button.size, windowData.uiZIndex, showHoverColor ? button.hoverBgColor : button.bgColor)
    windowData.uiZIndex -= 0.1

    renderLine(windowData.directXState, windowData, button.text, { i32(leftTextPadding) + button.position.x, i32(bottomTextPadding) + button.position.y }, 
        button.color, windowData.uiZIndex)
    windowData.uiZIndex -= 0.1

    return checkUiState(windowData, uiId, toRect(button.position, button.size))
}

renderVerticalScrollBar :: proc(windowData: ^WindowData, loc := #caller_location) -> UiActions {
    maxLinesOnScreen := getEditorSize(windowData).y / i32(windowData.font.lineHeight)
    totalLines := i32(len(windowData.screenGlyphs.lines))
    uiId := loc

    if totalLines == 1 { return {} }

    // draw background
    scrollWidth := windowData.editorPadding.right
    renderRect(windowData.directXState, float2{ f32(windowData.size.x) / 2.0 - f32(scrollWidth), -f32(windowData.size.y) / 2.0 }, 
        float2{ f32(scrollWidth), f32(windowData.size.y) }, windowData.maxZIndex, LINE_NUMBERS_BG_COLOR)

    scrollHeight := i32(f32(windowData.size.y * maxLinesOnScreen) / f32(maxLinesOnScreen + (totalLines - 1)))

    // NOTE: disable automatic top offset calculation if vertical scroll is selected by user 
    if windowData.activeUiId != uiId {
        windowData.verticalScrollTopOffset = i32(f32(windowData.screenGlyphs.lineIndex) / f32(maxLinesOnScreen + totalLines) * f32(windowData.size.y))
    }

    // draw scroll
    position := int2{ windowData.size.x / 2 - scrollWidth, windowData.size.y / 2 - windowData.verticalScrollTopOffset - scrollHeight }

    color := float4{ 1.0, 1.0, 1.0, 0.7 }
    hoverColor := float4{ 1.0, 1.0, 1.0, 1.0 }
    isHovered := windowData.hotUiId == uiId || windowData.activeUiId == uiId

    renderRect(windowData.directXState, 
        position,
        int2{ scrollWidth, scrollHeight }, 0.5, isHovered ? hoverColor : color)

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
