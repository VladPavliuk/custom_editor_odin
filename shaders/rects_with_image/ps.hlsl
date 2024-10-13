Texture2DArray objTexture : TEXTURE : register(t0);
SamplerState objSamplerState : SAMPLER : register(s0);

struct PSInput
{
    float4 positionSV : SV_POSITION;
    float2 texcoord : TEXCOORD;
    int imageIndex : IMAGE_INDEX;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET0;
};

PSOutput main(PSInput input)
{
    PSOutput output;

	float4 pixelColor = objTexture.Sample(objSamplerState, float3(input.texcoord.xy, input.imageIndex));

    output.pixelColor = pixelColor;

    return output;
}