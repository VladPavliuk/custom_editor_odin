package ui

@(private="file")
Button :: struct {
    position, size: [2]i32,
    bgColor, hoverBgColor: [4]f32,
    noBorder: bool,
    ignoreFocusUpdate: bool,
    disabled: bool,
}

renderButton :: proc{renderTextButton, renderImageButton}

@(private="file")
renderButton_Base :: proc(ctx: ^Context, button: Button, customId: i32 = 0, loc := #caller_location) -> Actions {
    Id := getId(customId, loc)
    position := button.position + getAbsolutePosition(ctx)
    pushElement(ctx, Id)

    uiRect := toRect(position, button.size)

    bgColor: [4]f32
    if !button.disabled {
        bgColor = button.bgColor

        if ctx.hotId == Id { 
            bgColor = button.hoverBgColor.a != 0.0 ? button.hoverBgColor : getDarkerColor(bgColor) 
            
            if ctx.activeId == Id { 
                bgColor = getDarkerColor(bgColor) 
            }
        }
    } else {
        bgColor = DARK_GRAY_COLOR
    }

    append(&ctx.commands, RectCommand{
        rect = uiRect,
        bgColor = bgColor,
    })

    if !button.noBorder {    
        append(&ctx.commands, BorderRectCommand{
            rect = uiRect,
            color = ctx.activeId == Id ? DARKER_GRAY_COLOR : GRAY_COLOR,
            thikness = 1,
        })
    }

    return button.disabled ? {} : checkUiState(ctx, Id, uiRect, button.ignoreFocusUpdate)
}

TextButton :: struct {
    using base: Button,
    text: string,
    color: [4]f32,
}

@(private="file")
renderTextButton :: proc(ctx: ^Context, button: TextButton, customId: i32 = 0, loc := #caller_location) -> Actions {
    actions := renderButton_Base(ctx, button.base, customId, loc)

    position := button.position + getAbsolutePosition(ctx)

    uiRect := toRect(position, button.size)
    uiRectSize := getRectSize(uiRect)

    textWidth := ctx.getTextWidth(button.text, ctx.font)
    textHeight := ctx.getTextHeight(ctx.font)

    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0

    fontColor := button.color.a != 0.0 ? button.color : WHITE_COLOR

    append(&ctx.commands, ClipCommand{
        rect = uiRect, 
    })
    append(&ctx.commands, TextCommand{
        text = button.text, 
        position = { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom },
        color = fontColor,
    })
    append(&ctx.commands, ResetClipCommand{})

    return actions
}

ImageButton :: struct {
    using base: Button,
    textureId: i32,
    texturePadding: i32,
} 

@(private="file")
renderImageButton :: proc(ctx: ^Context, button: ImageButton, customId: i32 = 0, loc := #caller_location) -> Actions {
    actions := renderButton_Base(ctx, button.base, customId, loc)

    position := button.position + getAbsolutePosition(ctx)

    size := button.size
    uiRect := toRect(position, button.size)

    uiRect.bottom += button.texturePadding
    uiRect.top -= button.texturePadding
    uiRect.left += button.texturePadding
    uiRect.right -= button.texturePadding

    position, size = fromRect(uiRect)

    append(&ctx.commands, ImageCommand{
        rect = uiRect,
        textureId = button.textureId,
    })

    return actions
}
