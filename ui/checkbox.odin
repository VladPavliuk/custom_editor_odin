package ui

Checkbox :: struct {
    text: string,
    checked: ^bool,
    position: [2]i32,
    color, bgColor, hoverBgColor: [4]f32,
}

renderCheckbox :: proc(ctx: ^Context, checkbox: Checkbox, customId: i32 = 0, loc := #caller_location) -> Actions {
    Id := getId(customId, loc)
    position := checkbox.position + getAbsolutePosition(ctx)
    pushElement(ctx, Id)

    textWidth := ctx.getTextWidth(checkbox.text, ctx.font)
    textHeight := ctx.getTextHeight(ctx.font)
    
    boxToTextPadding: i32 = 10
    boxSize := int2{ 16, 16 }
    boxPosition := int2{ position.x, position.y + (i32(textHeight) - boxSize.y) / 2 }

    uiRect := toRect(position, { i32(textWidth) + boxSize.x + boxToTextPadding, i32(textHeight) })
    uiRectSize := getRectSize(uiRect)
    
    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0 + f32(boxToTextPadding)

    append(&ctx.commands, TextCommand{
        text = checkbox.text, 
        position = { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom },
        color = checkbox.color,
    })

    checkboxRect := toRect(boxPosition, boxSize)

    if checkbox.checked^ {
        append(&ctx.commands, RectCommand{
            rect = checkboxRect,
            bgColor = WHITE_COLOR,
        })  
    }

    append(&ctx.commands, BorderRectCommand{
        rect = checkboxRect,
        color = ctx.activeId == Id ? DARK_GRAY_COLOR : DARKER_GRAY_COLOR,
        thikness = 1,
    })
    
    if ctx.activeId == Id {    
        append(&ctx.commands, BorderRectCommand{
            rect = uiRect,
            color = LIGHT_GRAY_COLOR,
            thikness = 1,
        })     
    }

    action := checkUiState(ctx, Id, uiRect)

    if .SUBMIT in action {
        checkbox.checked^ = !(checkbox.checked^)
    }

    return action
}
