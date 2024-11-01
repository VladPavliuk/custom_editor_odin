package ui

Scroll :: struct {
    bgRect: Rect,
    offset: ^i32,
    size: i32,
    color, hoverColor, bgColor: [4]f32,
    preventAutomaticScroll: bool,
}

beginScroll :: proc(ctx: ^Context) {
    append(&ctx.scrollableElements, make(map[Id]struct{}))
}

endScroll :: proc(ctx: ^Context, verticalScroll: Scroll, horizontalScroll: Scroll = {}, customId: i32 = 0, loc := #caller_location) -> (Actions, Actions) {
    customId := customId
    //TODO: there's this stupid duplication of renderVerticalScroll and renderHorizontalScroll, annoying!
    verticalScrollActions := renderVerticalScroll(ctx, verticalScroll, customId, loc)
    horizontalScrollActions: Actions = {}

    if horizontalScroll.offset != nil {
        customId += 1
        horizontalScrollActions = renderHorizontalScroll(ctx, horizontalScroll, customId, loc)
    }

    // if ctx.hotId in scrollableElements && abs(inputState.scrollDelta) > 0 {
    //     scrollAction += {.MOUSE_WHEEL_SCROLL}
    // }

    return verticalScrollActions, horizontalScrollActions
}

renderVerticalScroll :: proc(ctx: ^Context, scroll: Scroll, customId: i32 = 0, loc := #caller_location) -> Actions {
    assert(scroll.offset != nil)
    scrollableElements := pop(&ctx.scrollableElements)
    defer delete(scrollableElements)

    scrollId := getId(customId, loc)
    
    bgId := getId((customId + 1) * 99999999, loc)

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
    pushCommand(ctx, RectCommand{
        rect = bgRect,
        bgColor = scroll.bgColor,
    })

    bgAction := checkUiState(ctx, bgId, bgRect, true)

    // scroll
    isHover := ctx.activeId == scrollId || ctx.hotId == scrollId
    pushCommand(ctx, RectCommand{
        rect = scrollRect,
        bgColor = isHover ? scroll.hoverColor : scroll.color,
    })

    scrollAction := checkUiState(ctx, scrollId, scrollRect, true)

    validateScrollOffset :: proc(offset: ^i32, maxOffset: i32) {
        offset^ = max(0, offset^)
        offset^ = min(maxOffset, offset^)
    }

    if .ACTIVE in scrollAction {
        mouseY := screenToDirectXCoords(ctx.mousePosition, ctx).y

        delta := ctx.deltaMousePosition.y

        if mouseY < bgRect.bottom {
            delta = abs(delta)
        } else if mouseY > bgRect.top {
            delta = -abs(delta)
        }

        scroll.offset^ += delta

        validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.size)
    }

    if !scroll.preventAutomaticScroll && (ctx.hotId in scrollableElements || .MOUSE_WHEEL_SCROLL in bgAction || .MOUSE_WHEEL_SCROLL in scrollAction) {
        scroll.offset^ -= ctx.scrollDelta
        validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.size)
    }

    validateScrollOffset(scroll.offset, bgRect.top - bgRect.bottom - scroll.size)
    
    if ctx.hotId in scrollableElements && abs(ctx.scrollDelta) > 0 {
        scrollAction += {.MOUSE_WHEEL_SCROLL}
    }

    return scrollAction    
}

renderHorizontalScroll :: proc(ctx: ^Context, scroll: Scroll, customId: i32 = 0, loc := #caller_location) -> Actions {
    // assert(scroll.offset != nil)
    // scrollableElements := pop(&ctx.scrollableElements)
    // defer delete(scrollableElements)

    scrollId := getId(customId, loc)
    
    // bgId := getId((customId + 1) * 99999999, loc)

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
    pushCommand(ctx, RectCommand{
        rect = bgRect,
        bgColor = scroll.bgColor,
    })

    // scroll
    isHover := ctx.activeId == scrollId || ctx.hotId == scrollId
    
    pushCommand(ctx, RectCommand{
        rect = scrollRect,
        bgColor = isHover ? scroll.hoverColor : scroll.color,
    })

    scrollAction := checkUiState(ctx, scrollId, scrollRect, true)

    validateScrollOffset :: proc(offset: ^i32, maxOffset: i32) {
        offset^ = max(0, offset^)
        offset^ = min(maxOffset, offset^)
    }

    if .ACTIVE in scrollAction {
        mouseX := screenToDirectXCoords(ctx.mousePosition, ctx).x

        delta := ctx.deltaMousePosition.x

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
