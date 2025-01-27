package main

import "base:intrinsics"
import "core:math"
import "core:math/linalg"

getOrthoraphicsMatrix :: proc(viewWidth, viewHeight, nearZ, farZ: f32) -> mat4 {
    // todo: investigate why it does not work, prorably nearZ and farZ are messed up
    // l := -viewWidth / 2
    // r := viewWidth / 2
    // t := viewHeight / 2
    // b := -viewHeight / 2

    // return intrinsics.transpose(linalg.matrix_ortho3d(l, r, b, t, nearZ, farZ, true))

    range := 1.0 / (farZ - nearZ)

    return mat4{
        2.0 / viewWidth, 0, 0, 0,
        0, 2.0 / viewHeight, 0, 0,
        0, 0, range, 0,
        0, 0, -range * nearZ, 1,
    }
}

getTransformationMatrix :: proc(position, rotation, scale: float3) -> mat4 {
    return linalg.matrix4_translate(position) * linalg.matrix4_scale(scale)

    // todo: for now remove rotation
    //getRotationMatrix(rotation.x, rotation.y, rotation.z)
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
