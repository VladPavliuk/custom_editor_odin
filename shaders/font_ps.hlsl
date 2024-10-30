Texture2D<uint> rasterizedGlyphsTexture : TEXTURE : register(t0);

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
    
    float2 textureOffset : TEX_OFFSET;
    float2 textureScale : TEX_SCALE;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET0;
    // float objectItemId : SV_TARGET1;
};

PSOutput main(PSInput input)
{
    float4 glyphLocation = input.glyphLocation;
    PSOutput output;

    float2 textureCoords = input.textureOffset + input.texcoord * input.textureScale;

    uint value = rasterizedGlyphsTexture.Load(int3(
		(int)glyphLocation.z + ((int)glyphLocation.w - (int)glyphLocation.z) * textureCoords.x,
        (int)glyphLocation.y + ((int)glyphLocation.x - (int)glyphLocation.y) * textureCoords.y,
	0));

    //clip(value == 0 ? -1 : 1);

    float4 color = input.color;
    output.pixelColor = float4(color.x, color.y, color.z, color.w * ((float)value) / 255.0f);
    
    // output.pixelColor = float4(1.0, 0.0, 1.0, 1.0);
    // output.objectItemId = (float) input.objectItemId;
    
    return output;
}