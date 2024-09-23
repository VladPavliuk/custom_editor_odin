Texture2D objTexture : TEXTURE : register(t0);
SamplerState objSamplerState : SAMPLER : register(s0);

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

    float4 objectColor = objTexture.Sample(objSamplerState, input.texcoord.xy).xyzw;

    output.pixelColor = objectColor;
    // output.pixelColor = color;
    
    // output.pixelColor = float4(1.0, 0.0, 1.0, 1.0);
    // output.objectItemId = (float) input.objectItemId;
    
    return output;
}