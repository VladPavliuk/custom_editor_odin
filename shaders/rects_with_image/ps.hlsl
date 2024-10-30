Texture2DArray objTexture : TEXTURE : register(t0);
SamplerState objSamplerState : SAMPLER : register(s0);

struct PSInput
{
    float4 positionSV : SV_POSITION;
    float2 texcoord : TEXCOORD;
    int imageIndex : IMAGE_INDEX;
    float2 textureOffset : TEX_OFFSET;
    float2 textureScale : TEX_SCALE;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET0;
};

PSOutput main(PSInput input)
{
    PSOutput output;

    // float2 textureCoords = float2(input.textureOffset.x + input.texcoord.x * input.textureScale.x, input.textureOffset.y + input.texcoord.y * input.textureScale.y);
    float2 textureCoords = input.textureOffset + input.texcoord * input.textureScale;
	float4 pixelColor = objTexture.Sample(objSamplerState, float3(textureCoords, input.imageIndex));

    output.pixelColor = pixelColor;

    return output;
}