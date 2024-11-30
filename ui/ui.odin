package ui

import "base:runtime"

import "core:slice"

// TODO: make all them configurable
EMPTY_COLOR := [4]f32{ 0.0, 0.0, 0.0, 0.0 }
RED_COLOR := [4]f32{ 1.0, 0.0, 0.0, 1.0 }
GREEN_COLOR := [4]f32{ 0.0, 1.0, 0.0, 1.0 }
BLUE_COLOR := [4]f32{ 0.0, 0.0, 1.0, 1.0 }
YELLOW_COLOR := [4]f32{ 1.0, 1.0, 0.0, 1.0 }
WHITE_COLOR := [4]f32{ 1.0, 1.0, 1.0, 1.0 }
BLACK_COLOR := [4]f32{ 0.0, 0.0, 0.0, 1.0 }
LIGHT_GRAY_COLOR := [4]f32{ 0.5, 0.5, 0.5, 1.0 }
GRAY_COLOR := [4]f32{ 0.3, 0.3, 0.3, 1.0 }
DARKER_GRAY_COLOR := [4]f32{ 0.2, 0.2, 0.2, 1.0 }
DARK_GRAY_COLOR := [4]f32{ 0.1, 0.1, 0.1, 1.0 }

Id :: i64

Actions :: bit_set[Action; u32]

Action :: enum u32 {
    SUBMIT,
    RIGHT_CLICK,
    DOUBLE_CLICK,
    HOT,
    ACTIVE,
    GOT_ACTIVE,
    LOST_ACTIVE,
    FOCUSED,
    GOT_FOCUS,
    LOST_FOCUS,
    MOUSE_ENTER,
    MOUSE_LEAVE,
    MOUSE_WHEEL_SCROLL,
}

MouseStates :: bit_set[MouseState]

MouseState :: enum {
    LEFT_IS_DOWN,
    LEFT_WAS_DOWN,
    LEFT_WAS_UP,

    LEFT_WAS_DOUBLE_CLICKED,
    LEFT_IS_DOWN_AFTER_DOUBLE_CLICKED,

    RIGHT_IS_DOWN,
    RIGHT_WAS_DOWN,
    RIGHT_WAS_UP,
}

Key :: enum {
    NONE,
    ESC,
    ENTER,
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
}

Keys :: bit_set[Key]

CursorType :: enum {
    DEFAULT,
    VERTICAL_SIZE,
    HORIZONTAL_SIZE,
}

Element :: struct {
    id: Id,
    parent: ^Element,
}

BaseCommand :: struct {
    clipRect: Rect,
}

RectCommand :: struct {
    using base: BaseCommand,
    rect: Rect,
    bgColor: [4]f32,
}

BorderRectCommand :: struct {
    using base: BaseCommand,
    rect: Rect,
    color: [4]f32,
    thikness: i32,
}

ImageCommand :: struct {
    using base: BaseCommand,
    rect: Rect,
    textureId: i32,
}

TextCommand :: struct {
    using base: BaseCommand,
    text: string,
    position: [2]i32,
    color: [4]f32,
    maxWidth: i32, // optional, used to indicate max width (in pixels) that text should use
}

EditableTextCommand :: struct {
    using base: BaseCommand,
    // text: string,
    // position: [2]i32,
    // color: [4]f32,
}

// ClipCommand :: struct {
//     rect: Rect,
// }

// ResetClipCommand :: struct {}

pushCommand :: proc(ctx: ^Context, command: Command) {
    switch &c in command {
    case RectCommand: c.clipRect = ctx.clipRect
    case ImageCommand: c.clipRect = ctx.clipRect
    case BorderRectCommand: c.clipRect = ctx.clipRect
    case TextCommand: c.clipRect = ctx.clipRect
    case EditableTextCommand: c.clipRect = ctx.clipRect
    }
    
    append(&ctx.commands, command)
}

Command :: union{RectCommand, ImageCommand, BorderRectCommand, TextCommand, EditableTextCommand}

Context :: struct {
    //> set up by client
    font: rawptr,

    setCursor: proc(CursorType),

    getTextHeight: proc(font: rawptr) -> f32,
    getTextWidth: proc(text: string, font: rawptr) -> f32,

    clientSize: [2]i32, // should be updated by client

    closeIconId: i32,
    checkIconId: i32,
    //<

    deltaMousePosition: [2]i32,
    mousePosition: [2]i32,
    scrollDelta: i32,
    mouse: MouseStates,
    wasPressedKeys: Keys,

    clipRect: Rect,

    commands: [dynamic]Command,
    zIndex: f32,

    elements: [dynamic]Element,
    parentElementsStack: [dynamic]^Element,

    isAnyPopupOpened: ^bool,

    hotId: Id,
    prevHotId: Id,
    hotIdChanged: bool,
    tmpHotId: Id,

    activeId: Id,
    
    prevFocusedId: Id,
    focusedId: Id,
    focusedIdChanged: bool,
    tmpFocusedId: Id,

    scrollableElements: [dynamic]map[Id]struct{},
    
    parentPositionsStack: [dynamic][2]i32,

    activeAlert: ^Alert,
}

clearContext :: proc(ctx: ^Context) {
    delete(ctx.commands)
    delete(ctx.scrollableElements)
    delete(ctx.parentPositionsStack)
    delete(ctx.parentElementsStack)
    delete(ctx.elements)
    clearAlert(ctx)
}

@(private)
pushElement :: proc(ctx: ^Context, id: Id, isParent := false) {
    parent := len(ctx.parentElementsStack) == 0 ? nil : slice.last(ctx.parentElementsStack[:])

    element := Element{
        id = id,
        parent = parent,
    }
    append(&ctx.elements, element)

    if isParent {
        append(&ctx.parentElementsStack, &ctx.elements[len(ctx.elements) - 1])
    }
}

isSubElement :: proc(ctx: ^Context, parentId: Id, childId: Id) -> bool {
    if childId == 0 { return false }
    assert(parentId != 0)
    assert(childId != 0)
    childElement: ^Element

    for &element in ctx.elements {
        if element.id == childId {
            childElement = &element
            break
        }
    }

    // TODO: maybe, it's better to show some dev error
    if childElement == nil { return false }
    // assert(childElement != nil)

    for childElement.parent != nil {
        if childElement.parent.id == parentId { return true }
        childElement = childElement.parent
    }

    return false
}

getId :: proc(customIdentifier: i32, callerLocation: runtime.Source_Code_Location) -> i64 {
    return i64(customIdentifier + 1) * i64(callerLocation.line + 1) * i64(callerLocation.column) * i64(uintptr(raw_data(callerLocation.file_path)))
}

beginUi :: proc(using ctx: ^Context, initZIndex: f32) {
    clear(&ctx.commands)
    zIndex = initZIndex
    tmpHotId = 0
    focusedId = tmpFocusedId

    // if clicked on empty element - lost any focus
    if .LEFT_WAS_DOWN in ctx.mouse && hotId == 0 {
        tmpFocusedId = 0
    }
}

endUi :: proc(using ctx: ^Context, frameDelta: f64) {
    updateAlertTimeout(ctx, frameDelta)
    if ctx.activeAlert != nil {
        renderActiveAlert(ctx)
    }

    hotIdChanged = false
    if tmpHotId != hotId {
        prevHotId = hotId
        hotIdChanged = true
    }

    hotId = tmpHotId

    focusedIdChanged = false
    if tmpFocusedId != focusedId {
        prevFocusedId = focusedId
        focusedIdChanged = true
    }

    clear(&ctx.elements)
    assert(len(ctx.parentElementsStack) == 0)
}

setClipRect :: proc(ctx: ^Context, rect: Rect) {
    ctx.clipRect = rect
}

resetClipRect :: proc(ctx: ^Context) {
    ctx.clipRect = { 0, 0, 0, 0 }
}

putEmptyElement :: proc(ctx: ^Context, rect: Rect, ignoreFocusUpdate := false, customId: i32 = 0, loc := #caller_location) -> (Actions, i64) {
    id := getId(customId, loc)

    return checkUiState(ctx, id, rect, ignoreFocusUpdate), id
}

advanceZIndex :: proc(ctx: ^Context) {
    ctx.zIndex -= 0.1
}

@(private)
checkUiState :: proc(ctx: ^Context, Id: Id, rect: Rect, ignoreFocusUpdate := false) -> Actions {
    if len(ctx.scrollableElements) > 0 {
        ctx.scrollableElements[len(ctx.scrollableElements) - 1][Id] = {}
    }

    mousePosition := screenToDirectXCoords({ i32(ctx.mousePosition.x), i32(ctx.mousePosition.y) }, ctx)

    action: Actions = nil
    
    if ctx.activeId == Id {
        if .LEFT_WAS_UP in ctx.mouse || .RIGHT_WAS_UP in ctx.mouse {
            if ctx.hotId == Id {
                if .RIGHT_WAS_UP in ctx.mouse {
                    action += {.RIGHT_CLICK}
                } else {
                    action += {.SUBMIT}
                }
            }

            action += {.LOST_ACTIVE}
            ctx.activeId = {}
        } else {
            action += {.ACTIVE}
        }
    } else if ctx.hotId == Id {
        if .LEFT_WAS_DOWN in ctx.mouse || .RIGHT_WAS_DOWN in ctx.mouse {
            ctx.activeId = Id

            action += {.GOT_ACTIVE}

            if !ignoreFocusUpdate { ctx.tmpFocusedId = Id }
        }
    }

    if ctx.focusedIdChanged && ctx.focusedId == Id {
        action += {.GOT_FOCUS}
    } else if ctx.focusedIdChanged && ctx.prevFocusedId == Id {
        action += {.LOST_FOCUS}
    }

    if ctx.hotIdChanged && ctx.hotId == Id {
        action += {.MOUSE_ENTER}
    } else if ctx.hotIdChanged && ctx.prevHotId == Id {
        action += {.MOUSE_LEAVE}
    }
    
    if ctx.hotId == Id {
        action += {.HOT}

        if abs(ctx.scrollDelta) > 0 {
            action += {.MOUSE_WHEEL_SCROLL}
        }
    }

    if isInRect(rect, mousePosition) {
        ctx.tmpHotId = Id
    }

    if ctx.focusedId == Id {
        action += {.FOCUSED}
    }

    return action
}

getDarkerColor :: proc(color: [4]f32) -> [4]f32 {
    rgb := color.rgb * 0.8
    return { rgb.r, rgb.g, rgb.b, color.a }
}

getAbsolutePosition :: proc(Context: ^Context) -> [2]i32 {
    absolutePosition := [2]i32{ 0, 0 }

    for position in Context.parentPositionsStack {
        absolutePosition += position
    }

    return absolutePosition
}

screenToDirectXCoords :: proc(coords: [2]i32, ctx: ^Context) -> [2]i32 {
    return {
        coords.x - ctx.clientSize.x / 2,
        -coords.y + ctx.clientSize.y / 2,
    }
}

directXToScreenRect :: proc(rect: Rect, ctx: ^Context) -> Rect {
    return Rect{
        top = ctx.clientSize.y / 2 - rect.top, 
        bottom = ctx.clientSize.y / 2 - rect.bottom, 
        left = rect.left + ctx.clientSize.x / 2, 
        right = rect.right + ctx.clientSize.x / 2, 
    }
}

directXToScreenToCoords :: proc(coords: [2]i32, ctx: ^Context) -> [2]i32 {
    return {
        coords.x + ctx.clientSize.x / 2,
        coords.y + ctx.clientSize.x / 2,
    }
}
