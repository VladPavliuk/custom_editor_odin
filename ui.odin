package main

import "base:runtime"

UiCommandRect :: struct {
    rect: Rect,
    color: float4,
    hoverColor: float4,
}

UiCommandText :: struct {
    text: string,
    position: int2,
    // width: f32,
    // height: f32,
    color: float4,
}

UiCommandAction :: struct {
    onClick: proc(windowData: ^WindowData = nil),
    onActive: proc(windowData: ^WindowData = nil),
    onActiveLost: proc(windowData: ^WindowData = nil),
}

UiCommandVariant :: union {
	// ^Command_Jump,
	// ^Command_Clip,
	UiCommandRect,
	UiCommandText,
	UiCommandAction,
	// ^Command_Icon,
}

uiId :: runtime.Source_Code_Location

UiCommand :: struct {
    id: uiId,
	variant: UiCommandVariant,
}

uiCommands := make([dynamic]UiCommand)

UiButton :: struct {
    text: string,
    position, size: int2,
    color, bgColor, hoverBgColor: float4,
    onClick: proc(windowData: ^WindowData), 
}

renderButton :: proc(windowData: ^WindowData, button: UiButton, loc := #caller_location) {
    commandsButchId := loc
    
    textWidth := getTextWidth(button.text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    bottomTextPadding := (f32(button.size.y) - textHeight) / 2.0
    leftTextPadding := (f32(button.size.x) - textWidth) / 2.0

    append(&uiCommands, UiCommand{
        id = commandsButchId,
        variant = UiCommandAction{
            onClick = button.onClick,
        },
    })

    append(&uiCommands, UiCommand{
        id = commandsButchId,
        variant = UiCommandRect{
            rect = Rect{ button.position.y + button.size.y, button.position.y, button.position.x, button.position.x + button.size.x },
            color = button.bgColor,
            hoverColor = button.hoverBgColor,
        },
    })

    append(&uiCommands, UiCommand{
        id = commandsButchId,
        variant = UiCommandText{
            text = button.text,
            position = { i32(leftTextPadding) + button.position.x, i32(bottomTextPadding) + button.position.y },
            color = button.color,
        },
    })
}

screenToDirectXCoords :: proc(windowData: ^WindowData, coords: int2) -> int2 {
    return {
        coords.x - windowData.size.x / 2,
        -coords.y + windowData.size.y / 2,
    }
}

directXToScreenToCoords :: proc(windowData: ^WindowData, coords: int2) -> int2 {
    return {
        coords.x + windowData.size.x / 2,
        coords.y + windowData.size.x / 2,
    }
}
