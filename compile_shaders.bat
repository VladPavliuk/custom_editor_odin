@echo off
if not exist bin\ (
    mkdir bin
)

if not exist bin\shaders (
    mkdir bin\shaders
)

set vertex_shaders=testVertexShader
set pixel_shaders=textPixelShader

(for %%s in (%vertex_shaders%) do ( 
   fxc /Od /Zi /T vs_5_0 /Fo bin\shaders\%%s.fxc shaders\%%s.hlsl    
))

(for %%s in (%pixel_shaders%) do ( 
   fxc /Od /Zi /T ps_5_0 /Fo bin\shaders\%%s.fxc shaders\%%s.hlsl    
))

