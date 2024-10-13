cbuffer viewProjectionCB : register(b0)
{
    float4x4 projectionMatrix;
};

struct RectWithColor {
    float4x4 transformation;
    float4 color;
};

StructuredBuffer<RectWithColor> rects : register(t0);

struct VSInput
{
    float3 position : POSITION;
    float2 texcoord : TEXCOORD;
};

struct VSOutput
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

VSOutput main(VSInput input, uint instanceId : SV_InstanceID)
{
    VSOutput output;

    RectWithColor rect = rects.Load(instanceId);

    output.position = float4(input.position, 1.0f);
    
    // transpose
    output.position = mul(output.position, rect.transformation);
    output.position = mul(output.position, projectionMatrix);

    output.color = rect.color;

    return output;
}
