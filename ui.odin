package main

import "base:runtime"

import "core:fmt"

uiId :: i64

UiActions :: bit_set[UiAction; u32]

UiAction :: enum u32 {
    SUBMIT,
    HOT,
    ACTIVE,
    GOT_ACTIVE,
    LOST_ACTIVE,
    GOT_FOCUS,
    LOST_FOCUS,
    MOUSE_ENTER,
    MOUSE_LEAVE,
    MOUSE_WHEEL_SCROLL,
}

getUiId :: proc(customIdentifier: i32, callerLocation: runtime.Source_Code_Location) -> i64 {
    return i64(customIdentifier + 1) * i64(callerLocation.line + 1) * i64(uintptr(raw_data(callerLocation.file_path)))
}

beginUi :: proc(using ctx: ^UiContext, initZIndex: f32) {
    zIndex = initZIndex
    tmpHotId = 0
    tmpFocusedId = focusedId

    // if clicked on empty element - lost any focus
    if inputState.wasLeftMouseButtonDown && hotId == 0 {
        focusedId = 0
    }
}

endUi :: proc(using ctx: ^UiContext) {
    hotIdChanged = false
    if tmpHotId != hotId {
        prevHotId = hotId
        hotIdChanged = true
    }

    hotId = tmpHotId

    focusedIdChanged = false
    if tmpFocusedId != focusedId {
        prevFocusedId = tmpFocusedId
        focusedIdChanged = true
    }
}

// TODO: move it from here
renderEditorVerticalScrollBar :: proc() -> UiActions {
    maxLinesOnScreen := getEditorSize().y / i32(windowData.font.lineHeight)
    totalLines := i32(len(windowData.screenGlyphs.lines))

    if totalLines == 1 { return {} }

    scrollWidth := windowData.editorPadding.right
    scrollHeight := i32(f32(windowData.size.y * maxLinesOnScreen) / f32(maxLinesOnScreen + (totalLines - 1)))

    @(static)
    offset: i32 = 0

    beginScroll(&windowData.uiContext)

    action := endScroll(&windowData.uiContext, UiScroll{
        bgRect = {
            top = windowData.size.y / 2,
            bottom = -windowData.size.y / 2,
            left = windowData.size.x / 2 - scrollWidth,
            right = windowData.size.x / 2,
        },
        height = scrollHeight,
        offset = &offset,
        color = float4{ 0.7, 0.7, 0.7, 1.0 },
        hoverColor = float4{ 1.0, 1.0, 1.0, 1.0 },
        bgColor = float4{ 0.2, 0.2, 0.2, 1.0 },
    })

    if .ACTIVE in action {
        windowData.screenGlyphs.lineIndex = i32(f32(totalLines) * (f32(offset) / f32(windowData.size.y - scrollHeight)))

        // TODO: temporary fix, for some reasons it's possible to move vertical scroll bar below last line???
        windowData.screenGlyphs.lineIndex = min(i32(totalLines) - 1, windowData.screenGlyphs.lineIndex)
    } else {
        offset = i32(f32(windowData.screenGlyphs.lineIndex) / f32(maxLinesOnScreen + totalLines) * f32(windowData.size.y))
    }

    return action
}

putEmptyUiElement :: proc(ctx: ^UiContext, rect: Rect, customId: i32 = 0, loc := #caller_location) -> (uiId, UiActions) {
    uiId := getUiId(customId, loc)

    return uiId, checkUiState(ctx, uiId, rect)
}

advanceUiZIndex :: proc(uiContext: ^UiContext) {
    uiContext.zIndex -= 0.1
}

checkUiState :: proc(ctx: ^UiContext, uiId: uiId, rect: Rect, ignoreFocusUpdate := false) -> UiActions {
    if len(ctx.scrollableElements) > 0 {
        ctx.scrollableElements[len(ctx.scrollableElements) - 1][uiId] = {}
    }

    mousePosition := screenToDirectXCoords({ i32(inputState.mousePosition.x), i32(inputState.mousePosition.y) })

    action: UiActions = nil
    
    if ctx.activeId == uiId {
        if inputState.wasLeftMouseButtonUp {
            if ctx.hotId == uiId {
                action += {.SUBMIT}
            }

            action += {.LOST_ACTIVE}
            ctx.activeId = {}
        } else {
            action += {.ACTIVE}
        }
    } else if ctx.hotId == uiId {
        if inputState.wasLeftMouseButtonDown {
            ctx.activeId = uiId

            action += {.GOT_ACTIVE}

            if !ignoreFocusUpdate { ctx.focusedId = uiId }
        }
    }

    if ctx.focusedIdChanged && ctx.focusedId == uiId {
        action += {.GOT_FOCUS}
    } else if ctx.focusedIdChanged && ctx.prevFocusedId == uiId {
        action += {.LOST_FOCUS}
    }

    if ctx.hotIdChanged && ctx.hotId == uiId {
        action += {.MOUSE_ENTER}
    } else if ctx.hotIdChanged && ctx.prevHotId == uiId {
        action += {.MOUSE_LEAVE}
    }
    
    if ctx.hotId == uiId {
        action += {.HOT}

        if abs(inputState.scrollDelta) > 0 {
            action += {.MOUSE_WHEEL_SCROLL}
        }
    }

    if isInRect(rect, mousePosition) {
        ctx.tmpHotId = uiId
    }

    return action
}

getDarkerColor :: proc(color: float4) -> float4 {
    rgb := color.rgb * 0.8
    return { rgb.r, rgb.g, rgb.b, color.a }
}

getAbsolutePosition :: proc(uiContext: ^UiContext) -> int2 {
    absolutePosition := int2{ 0, 0 }

    for position in uiContext.parentPositionsStack {
        absolutePosition += position
    }

    return absolutePosition
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

screenToDirectXCoords :: proc(coords: int2) -> int2 {
    return {
        coords.x - windowData.size.x / 2,
        -coords.y + windowData.size.y / 2,
    }
}

directXToScreenToCoords :: proc(coords: int2) -> int2 {
    return {
        coords.x + windowData.size.x / 2,
        coords.y + windowData.size.x / 2,
    }
}
