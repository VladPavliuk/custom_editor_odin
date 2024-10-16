Texture2D<uint> byteObjTexture : TEXTURE : register(t0);

// IDEA: instad of cliping when part of glyph is outside of rect, just set it's alpha value to zero???

// 300-400ms without any clipping

// cbuffer solidColorCB : register(b0)
// {
//     float4 color;
// }

struct PSInput
{
    float4 positionSV : SV_POSITION;
    float2 texcoord : TEXCOORD;
    float4 glyphLocation : GLYPH_LOCATION;
    float4 color: COLOR;
    //float4 clipRect: CLIP_RECT;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET0;
    // float objectItemId : SV_TARGET1;
};

PSOutput main(PSInput input)
{
    //clip(input.positionSV.y - 200); // right side check

    float4 glyphLocation = input.glyphLocation;
    PSOutput output;

    uint value = byteObjTexture.Load(int3(
		(int)glyphLocation.z + ((int)glyphLocation.w - (int)glyphLocation.z) * input.texcoord.x,
        (int)glyphLocation.y + ((int)glyphLocation.x - (int)glyphLocation.y) * input.texcoord.y,
	0));

    //clip(value == 0 ? -1 : 1);

    float4 color = input.color;
    output.pixelColor = float4(color.x, color.y, color.z, color.w * ((float)value) / 255.0f);
    
    // output.pixelColor = float4(1.0, 0.0, 1.0, 1.0);
    // output.objectItemId = (float) input.objectItemId;
    
    return output;
}