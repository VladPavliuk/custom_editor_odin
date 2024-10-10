package ui

ResizeDirection :: enum {
    NONE,
    TOP,
    BOTTOM,
    LEFT,
    RIGHT,
}

putResizableRect :: proc(ctx: ^Context, rect: Rect, customId: i32 = 0, loc := #caller_location) -> ResizeDirection {
    direction := ResizeDirection.NONE

    resizeZoneSize :: 5
    rightRect := Rect{
        top = rect.top,
        bottom = rect.bottom,
        right = rect.right + resizeZoneSize,
        left = rect.right - resizeZoneSize,
    }
    rightBorderActions := putEmptyElement(ctx, rightRect, false, customId, loc)

    if .HOT in rightBorderActions || .ACTIVE in rightBorderActions {
        ctx.setCursor(.HORIZONTAL_SIZE)
    }

    if .ACTIVE in rightBorderActions {
        direction = .RIGHT
    }

    return direction
}
