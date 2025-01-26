package ui

import "core:mem"

Alert :: struct {
    text: string,
    timeout: f64,
    color, bgColor, hoverColor: [4]f32,
    originalTimeout: f64, // internal, don't specify it!
}

pushAlert :: proc(ctx: ^Context, alert: Alert, customId: i32 = 0, loc := #caller_location) {
    clearAlert(ctx)
    ctx.activeAlert = new(Alert)

    alert := alert
    alert.timeout = alert.timeout > 0.01 ? alert.timeout : 3.0
    alert.originalTimeout = alert.timeout
    mem.copy(ctx.activeAlert, &alert, size_of(Alert))
}

clearAlert :: proc(ctx: ^Context) {
    if ctx.activeAlert != nil {
        delete(ctx.activeAlert.text)
        free(ctx.activeAlert)
        ctx.activeAlert = nil
    }
}

updateAlertTimeout :: proc(ctx: ^Context, delta: f64) {
    if ctx.activeAlert == nil { return }

    ctx.activeAlert.timeout -= delta

    if ctx.activeAlert.timeout < 0.0 {
        clearAlert(ctx)
    }
}

renderActiveAlert :: proc(ctx: ^Context, customId: i32 = 0, loc := #caller_location) -> Actions {
    if ctx.activeAlert == nil { return {} }

    alert := ctx.activeAlert

    fadeOutDuration := 1.5
    fadeInDuration := 0.15

    customId := customId
    Id := getId(customId, loc)

    textWidth := ctx.getTextWidth(alert.text, ctx.font)
    textHeight := ctx.getTextHeight(ctx.font)
    textPadding := int2{ 10, 5 }
    targetAlertOffset := int2{ 15, 5 }

    alertRect := Rect{
        top = -ctx.clientSize.y / 2,
        bottom = -ctx.clientSize.y / 2 - i32(textHeight) - 2 * textPadding.y,
        right = ctx.clientSize.x / 2 - targetAlertOffset.x,
        left = ctx.clientSize.x / 2 - i32(textWidth) - 2 * textPadding.x - targetAlertOffset.x,
    }

    alertRectSize := getRectSize(alertRect)

    //> fade-in animation
    verticalOffset := targetAlertOffset.y + alertRectSize.y

    if fadeInDuration > alert.originalTimeout - alert.timeout {
        delta := (alert.originalTimeout - alert.timeout) / fadeInDuration
        verticalOffset = i32(f64(verticalOffset) * delta)
    }

    alertRect.bottom += verticalOffset
    alertRect.top += verticalOffset
    //<

    closeButtonPadding: i32 = 5
    closeButtonSize := alertRect.top - alertRect.bottom - closeButtonPadding * 2
    alertRect.left -= closeButtonSize

    //> fade-out animation
    transparency: f32 = 1.0

    if alert.timeout < fadeOutDuration {
        transparency = f32(alert.timeout * 1.0 / fadeOutDuration)
    }
    //<

    bgColor := alert.bgColor
    bgColor.a = transparency 
    
    pushCommand(ctx, RectCommand{
        rect = alertRect,
        bgColor = bgColor,
    })

    bottomTextPadding := (f32(alertRectSize.y) - textHeight) / 2.0
    leftTextPadding := (f32(alertRectSize.x) - textWidth) / 2.0

    fontColor := alert.color.a != 0.0 ? alert.color : WHITE_COLOR

    fontColor.a = transparency
    
    pushCommand(ctx, TextCommand{
        text = alert.text, 
        position = { i32(leftTextPadding) + alertRect.left, i32(bottomTextPadding) + alertRect.bottom },
        color = fontColor,
    })

    alertActions := checkUiState(ctx, Id, alertRect)

    // close button
    customId += 1
    closeBgColor := alert.bgColor
    closeBgColor.a = 0.0
    closeButtonActions, _ := renderButton(ctx, ImageButton{
        position = { alertRect.right - closeButtonSize - closeButtonPadding, alertRect.bottom + closeButtonPadding },
        size = { closeButtonSize, closeButtonSize },
        bgColor = closeBgColor,
        textureId = ctx.closeIconId,
        texturePadding = 2,
        noBorder = true,
    }, customId, loc) 

    if .SUBMIT in closeButtonActions {
        clearAlert(ctx)
    }

    if .HOT in alertActions || .HOT in closeButtonActions {
        alert.timeout = alert.originalTimeout - fadeInDuration
    }

    return alertActions
}
