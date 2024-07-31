cbuffer viewProjectionCB : register(b0)
{
    float4x4 projectionMatrix;
};

cbuffer transformationCB : register(b1)
{
    float4x4 modelTransformation;
};

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
    // float objectItemId : OBJECT_ID;
};

VSOutput main(VSInput input)
{
    VSOutput output;

    output.position = float4(input.position, 1.0f);
    
    output.position = mul(output.position, modelTransformation);
    output.position = mul(output.position, projectionMatrix);

    output.texcoord = input.texcoord;
    // output.objectItemId = objectId;

    return output;
}
