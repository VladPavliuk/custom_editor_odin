package main

int2 :: distinct [2]i32
int3 :: distinct [3]i32
int4 :: distinct [4]i32

float2 :: distinct [2]f32
float3 :: distinct [3]f32
float4 :: distinct [4]f32

mat4 :: distinct matrix[4, 4]f32

Rect :: struct {
    top: f32,
    bottom: f32,
    left: f32,
    right: f32,
}