package ui

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

setColorAlpha :: proc(color: float4, alpha: f32) -> float4 {
    return { color.r, color.g, color.b, alpha}
}

getOrDefaultColor :: proc(color, defaultColor: float4) -> float4 {
    return isValidColor(color) ? color : defaultColor
}

isValidColor :: proc(color: float4) -> bool {
    return color.a != 0
}

toRect :: proc(position, size: int2) -> Rect {
    return {
        top = position.y + size.y,
        bottom = position.y,
        left = position.x,
        right = position.x + size.x,
    }
}

fromRect :: proc(using rect: Rect) -> (int2, int2) {
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

clipRect :: proc(target, source: Rect) -> Rect {
    targetSize := getRectSize(target)
    sourceSize := getRectSize(source)

    // if source panel size is bigger then target panel size, do nothing 
    if sourceSize.x > targetSize.x || sourceSize.y > targetSize.y {
        return source
    }

    source := source

    // right side
    source.right = min(source.right, target.right)
    source.left = source.right - sourceSize.x

    // left side
    source.left = max(source.left, target.left)
    source.right = source.left + sourceSize.x

    // top side
    source.top = min(source.top, target.top)
    source.bottom = source.top - sourceSize.y

    // bottom side
    source.bottom = max(source.bottom, target.bottom)
    source.top = source.bottom + sourceSize.y

    return source
}

isInRect :: proc(rect: Rect, point: int2) -> bool {
	return point.x >= rect.left && point.x < rect.right && 
        point.y >= rect.bottom && point.y < rect.top
}
