cbuffer glyphLocationCB : register(b0)
{
    float4 glyphLocation;
    float2 glyphOffset;
    float glyphXAdvance;
}

Texture2D<uint> byteObjTexture : TEXTURE : register(t0);

// SamplerState objSamplerState : SAMPLER : register(s0);

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

    uint value = byteObjTexture.Load(int3(
		(int)glyphLocation.z + ((int)glyphLocation.w - (int)glyphLocation.z) * input.texcoord.x,
        (int)glyphLocation.y + ((int)glyphLocation.x - (int)glyphLocation.y) * input.texcoord.y,
	0));

    //clip(value == 0 ? -1 : 1);

    output.pixelColor = float4(1.0, 1.0, 1.0, ((float)value) / 255.0f);
    
    //output.pixelColor = objTexture.Sample(objSamplerState, input.texcoord.xy).xyzw;

    // output.pixelColor = float4(1.0, 0.0, 1.0, 1.0);
    // output.objectItemId = (float) input.objectItemId;
    
    return output;
}