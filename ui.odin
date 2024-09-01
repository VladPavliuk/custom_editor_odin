package main

import "core:fmt"

import "core:math/rand"

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

UiCommandOnClick :: struct {
    onClick: proc(data: rawptr = nil),
}

UiCommandVariant :: union {
	// ^Command_Jump,
	// ^Command_Clip,
	UiCommandRect,
	UiCommandText,
	UiCommandOnClick,
	// ^Command_Icon,
}

UiCommand :: struct {
    id: u64,
	variant: UiCommandVariant,
	// size:    i32, 
}

// startUi :: proc() {

// }
uiCommands := make([dynamic]UiCommand)
// currentUiZIndex: f32

renderButton :: proc(windowData: ^WindowData, text: string, 
    position: int2, size: int2, 
    color: float4, bgColor: float4, hoverBgColor: float4,
    onClick: proc(data: rawptr)) {
    textWidth := getTextWidth(text, &windowData.font)
    textHeight := getTextHeight(&windowData.font)

    // mousePosition := screenToDirectXCoords(windowData, { i32(windowData.mousePosition.x), i32(windowData.mousePosition.y) })

    bottomTextPadding := (f32(size.y) - textHeight) / 2.0
    leftTextPadding := (f32(size.x) - textWidth) / 2.0

    // isHovered := isInRect({ position.y, position.y + size.y, position.x, position.x + size.x }, mousePosition)

    // bgColor := isHovered ? bgColor : hoverBgColor

    // renderRect(windowData.directXState, { f32(position.x), f32(position.y) }, { f32(size.x), f32(size.y) }, currentUiZIndex, bgColor)
    // currentUiZIndex -= 0.1
    // renderLine(windowData.directXState, windowData, text, { i32(leftTextPadding) + position.x, i32(bottomTextPadding) + position.y }, 
    //     color, currentUiZIndex)
    // currentUiZIndex -= 0.1

    commandsButchId := rand.uint64()

    append(&uiCommands, UiCommand{
        id = commandsButchId,
        variant = UiCommandOnClick{
            onClick = onClick,
        },
    })

    append(&uiCommands, UiCommand{
        id = commandsButchId,
        variant = UiCommandRect{
            rect = Rect{ position.y + size.y, position.y, position.x, position.x + size.x },
            color = bgColor,
            hoverColor = hoverBgColor,
        },
    })

    append(&uiCommands, UiCommand{
        id = commandsButchId,
        variant = UiCommandText{
            text = text,
            position = { i32(leftTextPadding) + position.x, i32(bottomTextPadding) + position.y },
            // width = textWidth,
            color = color,
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
