package ui

Label :: struct {
    text: string,
    position: [2]i32,
    color: [4]f32,
}

renderLabel :: proc(ctx: ^Context, label: Label, customId: i32 = 0, loc := #caller_location) -> Actions {
    position := label.position + getAbsolutePosition(ctx)
    actions := Actions{}

    pushCommand(ctx, TextCommand{
        text = label.text, 
        position = position,
        color = label.color,
    })

    return actions
}
