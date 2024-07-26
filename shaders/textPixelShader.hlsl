struct PSInput
{
    float4 positionSV : SV_POSITION;
    float2 texcoord : TEXCOORD;
    //float objectItemId : OBJECT_ID;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET;
    // float objectItemId : SV_TARGET1;
};

PSOutput main(PSInput input)
{
    PSOutput output;
    
    output.pixelColor = float4(0.0, 1.0, 0.0, 1.0);
    // output.objectItemId = (float) input.objectItemId;
    
    return output;
}