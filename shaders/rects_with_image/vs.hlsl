cbuffer viewProjectionCB : register(b0)
{
    float4x4 projectionMatrix;
};

struct RectWithImage {
    float4x4 transformation;
    int imageIndex;
};

StructuredBuffer<RectWithImage> rects : register(t0);

struct VSInput
{
    float3 position : POSITION;
    float2 texcoord : TEXCOORD;
};

struct VSOutput
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD;
    int imageIndex : IMAGE_INDEX;
};

VSOutput main(VSInput input, uint instanceId : SV_InstanceID)
{
    VSOutput output;

    RectWithImage rect = rects.Load(instanceId);

    output.position = float4(input.position, 1.0f);
    
    // transpose
    output.position = mul(output.position, rect.transformation);
    output.position = mul(output.position, projectionMatrix);

    output.texcoord = input.texcoord;
    output.imageIndex = rect.imageIndex;

    return output;
}
