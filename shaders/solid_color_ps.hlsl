cbuffer solidColorCB : register(b0)
{
    float4 color;
}

struct PSInput
{
    float4 positionSV : SV_POSITION;
    float2 texcoord : TEXCOORD;
    //float objectItemId : OBJECT_ID;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET0;
    // float objectItemId : SV_TARGET1;
};

PSOutput main(PSInput input)
{
    PSOutput output;

    //clip(value == 0 ? -1 : 1);

    output.pixelColor = color;
    
    // output.pixelColor = float4(1.0, 0.0, 1.0, 1.0);
    // output.objectItemId = (float) input.objectItemId;
    
    return output;
}