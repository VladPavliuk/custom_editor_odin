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

    append(&ctx.commands, RectCommand{
        rect = uiRect,
        bgColor = bgColor,
    })

    hasFocus := ctx.focusedId == Id || ctx.hotId == Id
    append(&ctx.commands, BorderRectCommand{
        rect = uiRect,
        color = BLACK_COLOR,
        thikness = hasFocus ? 2 : 1,
    })

    textHeight := ctx.getTextHeight(ctx.font)
    
    actions := checkUiState(ctx, Id, uiRect)

    if ctx.focusedId == Id {
        append(&ctx.commands, ClipCommand{
            rect = uiRect,
        })
        append(&ctx.commands, EditableTextCommand{})
        append(&ctx.commands, ResetClipCommand{})
    } else {    
        append(&ctx.commands, ClipCommand{
            rect = uiRect,
        })
        append(&ctx.commands, TextCommand{
            text = textField.text, 
            position = { uiRect.left + 5, uiRect.bottom + uiRectSize.y / 2 - i32(textHeight) / 2 },
            color = BLACK_COLOR,
        })
        append(&ctx.commands, ResetClipCommand{})
    }

    return actions, Id
}
