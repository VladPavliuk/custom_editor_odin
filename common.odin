package main

import "core:time"

// just to simplify debuging
import fmt "core:fmt"
fmt :: fmt

int2 :: [2]i32
int3 :: [3]i32
int4 :: [4]i32

float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32

mat4 :: distinct matrix[4, 4]f32

debugTimer: time.Stopwatch
timeElapsedTotal: f64 = 0.0
timeElapsedCount: i32 = 0

startTimer :: proc() {
    time.stopwatch_start(&debugTimer)
}

stopTimer :: proc() {
    time.stopwatch_stop(&debugTimer)
    
    elapsed := time.duration_microseconds(debugTimer._accumulation)
    timeElapsedTotal += elapsed
    timeElapsedCount += 1
    fmt.printfln("duration, avg: %f ms, %f ms", elapsed, timeElapsedTotal / f64(timeElapsedCount))
    time.stopwatch_reset(&debugTimer)
}

toFloat2 :: proc(a: int2) -> float2 {
    return { f32(a.x), f32(a.y) }
}