cbuffer viewProjectionCB : register(b0)
{
    float4x4 projectionMatrix;
};

struct FontGlyph {
    int4 sourceRect;
    float4x4 targetTransformation;
    float4 color;

    float2 textureOffset;
    float2 textureScale;
};

StructuredBuffer<FontGlyph> fontGlyphs : register(t0);
//StructuredBuffer<float4> clipRects : register(t1);

// cbuffer objectIdCB : register(b2)
// {
//     float objectId;
// }

struct VSInput
{
    float3 position : POSITION;
    float2 texcoord : TEXCOORD;
};

struct VSOutput
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD;
    float4 glyphLocation : GLYPH_LOCATION;
    float4 color: COLOR;
    
    float2 textureOffset : TEX_OFFSET;
    float2 textureScale : TEX_SCALE;
};

VSOutput main(VSInput input, uint instanceId : SV_InstanceID)
{
    VSOutput output;

    FontGlyph fontGlyph = fontGlyphs.Load(instanceId);

    output.position = float4(input.position, 1.0f);
    
    // transpose
    output.position = mul(output.position, fontGlyph.targetTransformation);
    output.position = mul(output.position, projectionMatrix);

    output.texcoord = input.texcoord;
    output.glyphLocation = fontGlyph.sourceRect;
    output.color = fontGlyph.color;
    output.textureOffset = fontGlyph.textureOffset;
    output.textureScale = fontGlyph.textureScale;

    return output;
}
