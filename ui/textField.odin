package ui

TextField :: struct {
    text: string,
    initSelection: [2]i32,
    position, size: [2]i32,
    bgColor: [4]f32,
}

renderTextField :: proc(ctx: ^Context, textField: TextField, customId: i32 = 0, loc := #caller_location) -> (Actions, Id) {    
    Id := getId(customId, loc)
    position := textField.position + getAbsolutePosition(ctx)
    pushElement(ctx, Id)

    uiRect := toRect(position, textField.size)
    uiRectSize := getRectSize(uiRect)

    bgColor := WHITE_COLOR

    if ctx.hotId == Id { 
        bgColor = getDarkerColor(bgColor) 
        
        if ctx.activeId == Id { 
            bgColor = getDarkerColor(bgColor) 
        }
    }

    pushCommand(ctx, RectCommand{
        rect = uiRect,
        bgColor = bgColor,
    })

    hasFocus := ctx.focusedId == Id || ctx.hotId == Id
    pushCommand(ctx, BorderRectCommand{
        rect = uiRect,
        color = BLACK_COLOR,
        thikness = hasFocus ? 2 : 1,
    })

    textHeight := ctx.getTextHeight(ctx.font)
    
    actions := checkUiState(ctx, Id, uiRect)

    if ctx.focusedId == Id {
        // pushCommand(ctx, ClipCommand{
        //     rect = uiRect,
        // })
        pushCommand(ctx, EditableTextCommand{})
        // pushCommand(ctx, ResetClipCommand{})
    } else {
        // pushCommand(ctx, ClipCommand{
        //     rect = uiRect,
        // })
        pushCommand(ctx, TextCommand{
            text = textField.text, 
            position = { uiRect.left + 5, uiRect.bottom + uiRectSize.y / 2 - i32(textHeight) / 2 },
            color = BLACK_COLOR,
        })
        // pushCommand(ctx, ResetClipCommand{})
    }

    return actions, Id
}
