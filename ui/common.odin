package ui

import "core:fmt"
fmt :: fmt
print :: fmt.println

int2 :: [2]i32
int3 :: [3]i32
int4 :: [4]i32

float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32

mat4 :: distinct matrix[4, 4]f32

Rect :: struct {
    top: i32,
    bottom: i32,
    left: i32,
    right: i32,
}

RectF :: struct {
    top: f32,
    bottom: f32,
    left: f32,
    right: f32,
}

setColorAlpha :: proc(color: float4, alpha: f32) -> float4 {
    return { color.r, color.g, color.b, alpha}
}

getOrDefaultColor :: proc(color, defaultColor: float4) -> float4 {
    return isValidColor(color) ? color : defaultColor
}

isValidColor :: proc(color: float4) -> bool {
    return color.a != 0
}

toRect :: proc{toRect_Int, toRect_Float}

toRect_Int :: proc(position, size: int2) -> Rect {
    return {
        top = position.y + size.y,
        bottom = position.y,
        left = position.x,
        right = position.x + size.x,
    }
}

toRect_Float :: proc(position, size: float2) -> RectF {
    return {
        top = position.y + size.y,
        bottom = position.y,
        left = position.x,
        right = position.x + size.x,
    }
}

toFloatRect :: proc(a: Rect) -> RectF {
    return {
        top = f32(a.top),
        bottom = f32(a.bottom),
        left = f32(a.left),
        right = f32(a.right),
    }
}

toIntRect :: proc(a: RectF) -> Rect {
    return {
        top = i32(a.top),
        bottom = i32(a.bottom),
        left = i32(a.left),
        right = i32(a.right),
    }
}

fromRect :: proc{fromRect_Int, fromRect_Float}

fromRect_Int :: proc(using rect: Rect) -> (int2, int2) {
    return { left, bottom }, { right - left, top - bottom }
}

fromRect_Float :: proc(using rect: RectF) -> (float2, float2) {
    return { left, bottom }, { right - left, top - bottom }
}

getRectSize :: proc(using rect: Rect) -> int2 {
    return {
        right - left,
        top - bottom,
    }
}

shrinkRect :: proc(using rect: Rect, amount: i32) -> Rect {
    return Rect {
        top = top - amount,
        bottom = bottom + amount,
        left = left + amount,
        right = right - amount,
    }
}

fitChildRect :: proc(child, parent: Rect) -> Rect {
    childPosition, childSize := fromRect(child)
    parentPosition, parentSize := fromRect(parent)
    assert(childSize.x > 0 && childSize.y > 0 && parentSize.x > 0 && parentSize.y > 0)
    assert(parentSize.y >= childSize.y && parentSize.y >= childSize.y)

    childPosition.x -= max(0, child.right - parent.right)
    childPosition.x += max(0, parent.left - child.left)

    childPosition.y -= max(0, child.top - parent.top)
    childPosition.y += max(0, parent.bottom - child.bottom)

    return toRect(childPosition, childSize)
}

fitRectOnWindow :: proc{fitRectOnWindow_Rect, fitRectOnWindow_Pos_Size}

fitRectOnWindow_Rect :: proc(rect: Rect, ctx: ^Context) -> Rect {
    windowRect := Rect{
        top = ctx.clientSize.y / 2,
        bottom = -ctx.clientSize.y / 2,
        right = ctx.clientSize.x / 2,
        left = -ctx.clientSize.x / 2,
    }

    return fitChildRect(rect, windowRect)    
}

fitRectOnWindow_Pos_Size :: proc(position: int2, size: int2, ctx: ^Context) -> (int2, int2) {
    windowRect := Rect{
        top = ctx.clientSize.y / 2,
        bottom = -ctx.clientSize.y / 2,
        right = ctx.clientSize.x / 2,
        left = -ctx.clientSize.x / 2,
    }

    rect := fitChildRect(toRect(position, size), windowRect)    
    return fromRect(rect)
}

clipRect :: proc{clipRect_Int, clipRect_Float}

clipRect_Int :: proc(a, b: Rect) -> Rect {
    return Rect{
        top = min(a.top, b.top),
        bottom = max(a.bottom, b.bottom),
        left = max(a.left, b.left),
        right = min(a.right, b.right),
    }
}

clipRect_Float :: proc(a, b: RectF) -> RectF {
    return RectF{
        top = min(a.top, b.top),
        bottom = max(a.bottom, b.bottom),
        left = max(a.left, b.left),
        right = min(a.right, b.right),
    }
}

normalizeClippedToOriginal :: proc(clipped, original: Rect) -> (offset: [2]f32, scale: [2]f32){
    originalRectSize := getRectSize(original)
    clippedRectSize := getRectSize(clipped)

    scaleX := f32(clippedRectSize.x) / f32(originalRectSize.x)
    offsetX := f32(clipped.left - original.left) / f32(originalRectSize.x)

    scaleY := f32(clippedRectSize.y) / f32(originalRectSize.y)
    offsetY := f32(original.top - clipped.top) / f32(originalRectSize.y)

    return { offsetX, offsetY }, { scaleX, scaleY }
}

isValidRect :: proc{isValidRect_Int, isValidRect_Float}

isValidRect_Int :: proc(rect: Rect) -> bool {
    return rect.right > rect.left && rect.top > rect.bottom
}

isValidRect_Float :: proc(rect: RectF) -> bool {
    return rect.right > rect.left && rect.top > rect.bottom
}

// clipRect :: proc(target, source: Rect) -> Rect {
//     targetSize := getRectSize(target)
//     sourceSize := getRectSize(source)

//     // if source panel size is bigger then target panel size, do nothing 
//     if sourceSize.x > targetSize.x || sourceSize.y > targetSize.y {
//         return source
//     }

//     source := source

//     // right side
//     source.right = min(source.right, target.right)
//     source.left = source.right - sourceSize.x

//     // left side
//     source.left = max(source.left, target.left)
//     source.right = source.left + sourceSize.x

//     // top side
//     source.top = min(source.top, target.top)
//     source.bottom = source.top - sourceSize.y

//     // bottom side
//     source.bottom = max(source.bottom, target.bottom)
//     source.top = source.bottom + sourceSize.y

//     return source
// }

isInRect :: proc(rect: Rect, point: int2) -> bool {
	return point.x >= rect.left && point.x < rect.right && 
        point.y >= rect.bottom && point.y < rect.top
}
