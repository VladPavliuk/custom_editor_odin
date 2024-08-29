cbuffer viewProjectionCB : register(b0)
{
    float4x4 projectionMatrix;
};

struct FontGlyph {
    int4 sourceRect;
    float4x4 targetTransformation;
};

StructuredBuffer<FontGlyph> fontGlyphs : register(t0);

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
    // float objectItemId : OBJECT_ID;
    // uint instanceId : INSTANCE_ID;
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
    // output.objectItemId = objectId;

    return output;
}
