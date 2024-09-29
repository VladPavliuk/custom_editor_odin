package main

// just to simplify debuging
import fmt "core:fmt"
fmt :: fmt

int2 :: distinct [2]i32
int3 :: distinct [3]i32
int4 :: distinct [4]i32

float2 :: distinct [2]f32
float3 :: distinct [3]f32
float4 :: distinct [4]f32

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

isInRect :: proc(rect: Rect, point: int2) -> bool {
	return point.x >= rect.left && point.x < rect.right && 
        point.y >= rect.bottom && point.y < rect.top
}