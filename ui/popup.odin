package ui

import "core:slice"

Popup :: struct {
    position, size: [2]i32,
    bgColor: [4]f32,
    isOpen: ^bool,
    clipRect: Rect,
}

beginPopup :: proc(ctx: ^Context, popup: Popup, customId: i32 = 0, loc := #caller_location) -> bool {
    assert(popup.isOpen != nil)
    if !popup.isOpen^ { return false }

    position := popup.position
    bgRect := toRect(position, popup.size) 

    //> make sure that popup is on the screen
    bgRect = clipRect(popup.clipRect, bgRect)
    position, _ = fromRect(bgRect)  
    //<

    ctx.isAnyPopupOpened = popup.isOpen

    Id := getId(customId, loc)
    pushElement(ctx, Id, true)
    append(&ctx.parentPositionsStack, position)

    bgActions := putEmptyElement(ctx, bgRect, true, customId, loc)
    
    append(&ctx.commands, RectCommand{
        rect = bgRect,
        bgColor = popup.bgColor,
    })

    return true
}

endPopup :: proc(ctx: ^Context) {
    popupElement := slice.last(ctx.parentElementsStack[:])

    if ctx.focusedIdChanged && !isSubElement(ctx, popupElement.id, ctx.focusedId) {
        ctx.isAnyPopupOpened^ = false
    }
    
    pop(&ctx.parentPositionsStack)
    pop(&ctx.parentElementsStack)
}
