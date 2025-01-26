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
renderButton_Base :: proc(ctx: ^Context, button: Button, customId: i32 = 0, loc := #caller_location) -> (Actions, Id) {
    id := getId(customId, loc)
    position := button.position + getAbsolutePosition(ctx)
    pushElement(ctx, id)

    uiRect := toRect(position, button.size)

    bgColor: [4]f32
    if !button.disabled {
        bgColor = button.bgColor

        if ctx.hotId == id { 
            bgColor = button.hoverBgColor.a != 0.0 ? button.hoverBgColor : getDarkerColor(bgColor) 
            
            if ctx.activeId == id { 
                bgColor = getDarkerColor(bgColor) 
            }
        }
    } else {
        bgColor = DARK_GRAY_COLOR
    }

    pushCommand(ctx, RectCommand{
        rect = uiRect,
        bgColor = bgColor,
    })

    if !button.noBorder {
        pushCommand(ctx, BorderRectCommand{
            rect = uiRect,
            color = ctx.activeId == id ? DARKER_GRAY_COLOR : GRAY_COLOR,
            thikness = 1,
        })
    }

    return button.disabled ? {} : checkUiState(ctx, id, uiRect, button.ignoreFocusUpdate), id
}

TextButton :: struct {
    using base: Button,
    text: string,
    color: [4]f32,
}

@(private="file")
renderTextButton :: proc(ctx: ^Context, button: TextButton, customId: i32 = 0, loc := #caller_location) -> (Actions, Id) {
    actions, id := renderButton_Base(ctx, button.base, customId, loc)

    position := button.position + getAbsolutePosition(ctx)

    uiRect := toRect(position, button.size)
    uiRectSize := getRectSize(uiRect)

    textWidth := ctx.getTextWidth(button.text, ctx.font)
    textHeight := ctx.getTextHeight(ctx.font)

    bottomTextPadding := (f32(uiRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(uiRectSize.x) - textWidth) / 2.0

    fontColor := button.color.a != 0.0 ? button.color : WHITE_COLOR

    // pushCommand(ctx, ClipCommand{
    //     rect = uiRect, 
    // })
    pushCommand(ctx, TextCommand{
        text = button.text, 
        position = { i32(leftTextPadding) + uiRect.left, i32(bottomTextPadding) + uiRect.bottom },
        color = fontColor,
    })
    // pushCommand(ctx, ResetClipCommand{})

    return actions, id
}

ImageButton :: struct {
    using base: Button,
    textureId: i32,
    texturePadding: i32,
} 

@(private="file")
renderImageButton :: proc(ctx: ^Context, button: ImageButton, customId: i32 = 0, loc := #caller_location) -> (Actions, Id) {
    actions, id := renderButton_Base(ctx, button.base, customId, loc)

    position := button.position + getAbsolutePosition(ctx)

    size := button.size
    uiRect := toRect(position, button.size)

    uiRect.bottom += button.texturePadding
    uiRect.top -= button.texturePadding
    uiRect.left += button.texturePadding
    uiRect.right -= button.texturePadding

    position, size = fromRect(uiRect)

    pushCommand(ctx, ImageCommand{
        rect = uiRect,
        textureId = button.textureId,
    })

    return actions, id
}
