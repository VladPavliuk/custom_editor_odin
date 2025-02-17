package ui

Panel :: struct {
    title: string,
    position, size: ^[2]i32,
    bgColor, hoverBgColor, borderColor: [4]f32,
}

beginPanel :: proc(ctx: ^Context, panel: Panel, open: ^bool, customId: i32 = 0, loc := #caller_location) -> Actions {
    customId := customId
    Id := getId(customId, loc)
    pushElement(ctx, Id, true)

    headerId := getId((customId + 1) * 999999, loc)
    
    panelRect := toRect(panel.position^, panel.size^)

    textHeight := i32(ctx.getTextHeight(ctx.font))

    headerRect := Rect{ 
        top = panelRect.top,  
        bottom = panelRect.top - textHeight,
        left = panelRect.left,
        right = panelRect.right,
    }

    //> make sure that panel is on the screen
    panelRect = fitRectOnWindow(panelRect, ctx)
    panel.position^, _ = fromRect(panelRect)
    //<

    // panel body
    pushCommand(ctx, RectCommand{
        rect = panelRect,
        bgColor = panel.bgColor,
    })

    // panel header
    headerBgColor := getDarkerColor(panel.bgColor)

    if ctx.hotId == headerId { headerBgColor = getDarkerColor(headerBgColor) }
    if ctx.activeId == headerId { headerBgColor = getDarkerColor(headerBgColor) }

    pushCommand(ctx, RectCommand{
        rect = headerRect,
        bgColor = headerBgColor,
    })

    // panel title
    pushCommand(ctx, TextCommand{
        text = panel.title,
        position = { panelRect.left, panelRect.top - textHeight },
        color = WHITE_COLOR,
    })

    panelAction := checkUiState(ctx, Id, panelRect)
    headerAction := checkUiState(ctx, headerId, headerRect)

    // panel close button
    customId += 1
    closeButtonSize := headerRect.top - headerRect.bottom
    closeButtonsActions, _ := renderButton(ctx, ImageButton{
        position = { headerRect.right - closeButtonSize, headerRect.bottom },
        size = { closeButtonSize, closeButtonSize },
        bgColor = headerBgColor,
        textureId = ctx.closeIconId,
        texturePadding = 2,
        noBorder = true,
    }, customId, loc)
    
    if .SUBMIT in closeButtonsActions {
        open^ = false
    }

    borderColor := getOrDefaultColor(panel.borderColor, GRAY_COLOR)
    
    pushCommand(ctx, BorderRectCommand{
        rect = toRect(panel.position^, panel.size^),
        thikness = 1,
        color = borderColor,
    })

    if .ACTIVE in headerAction {
        panel.position.x += ctx.deltaMousePosition.x
        panel.position.y -= ctx.deltaMousePosition.y

        panel.position^, _ = fitRectOnWindow(panel.position^, panel.size^, ctx)
    }

    append(&ctx.parentPositionsStack, panel.position^)

    return panelAction
}

endPanel :: proc(ctx: ^Context) {
    pop(&ctx.parentPositionsStack)
    pop(&ctx.parentElementsStack)
}
