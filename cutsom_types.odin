package main

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

getRectSize :: proc(rect: Rect) -> int2 {
    return {
        rect.right - rect.left,        
        rect.top - rect.bottom,        
    }
}

isInRect :: proc(rect: Rect, point: int2) -> bool {
	return point.x >= rect.left && point.x < rect.right && 
        point.y >= rect.bottom && point.y < rect.top
}