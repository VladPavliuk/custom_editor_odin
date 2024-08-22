package main

import "core:math"

getOrthoraphicsMatrix :: proc(viewWidth, viewHeight, nearZ, farZ: f32) -> mat4 {
    range := 1.0 / (farZ - nearZ)

    return mat4{
        2.0 / viewWidth, 0, 0, 0,
        0, 2 / viewHeight, 0, 0,
        0, 0, range, 0,
        0, 0, -range * nearZ, 1,
    }
}

getTransformationMatrix :: proc(position, rotation, scale: float3) -> mat4 {
    return getScaleMatrix(scale.x, scale.y, scale.z) *
        getTranslationMatrix(position.x, position.y, position.z) * 
        getRotationMatrix(rotation.x, rotation.y, rotation.z)
} 

getTranslationMatrix :: proc(x, y, z: f32) -> mat4 {
    return mat4{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        x, y, z, 1,
    }
}

getRotationMatrix :: proc(pitch, roll, yaw: f32) -> mat4{
    cp := math.cos(pitch)
    sp := math.sin(pitch)

    cy := math.cos(yaw)
    sy := math.sin(yaw)

    cr := math.cos(roll)
    sr := math.sin(roll)

    return mat4{
        cr * cy + sr * sp * sy, sr * cp, sr * sp * cy - cr * sy, 0,
        cr * sp * sy - sr * cy, cr * cp, sr * sy + cr * sp * cy, 0,
        cp * sy               , -sp    , cp * cy               , 0,
        0                     ,0       ,0                      , 1,
    }
}

getScaleMatrix :: proc(x, y, z: f32) -> mat4 {
    return mat4{
        x, 0, 0, 0,
        0, y, 0, 0,
        0, 0, z, 0,
        0, 0, 0, 1,
    }
}