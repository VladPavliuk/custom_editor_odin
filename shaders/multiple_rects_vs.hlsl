cbuffer viewProjectionCB : register(b0)
{
    float4x4 projectionMatrix;
};

struct Rect {
    float4x4 transformation;
};

StructuredBuffer<Rect> rects : register(t0);

struct VSInput
{
    float3 position : POSITION;
    float2 texcoord : TEXCOORD;
};

struct VSOutput
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD;
};

VSOutput main(VSInput input, uint instanceId : SV_InstanceID)
{
    VSOutput output;

    Rect rect = rects.Load(instanceId);

    output.position = float4(input.position, 1.0f);
    
    // transpose
    output.position = mul(output.position, rect.transformation);
    output.position = mul(output.position, projectionMatrix);

    output.texcoord = input.texcoord;

    return output;
}
