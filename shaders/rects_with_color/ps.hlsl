struct PSInput
{
    float4 positionSV : SV_POSITION;
    float4 color : COLOR;
};

struct PSOutput
{
    float4 pixelColor : SV_TARGET0;
};

PSOutput main(PSInput input)
{
    PSOutput output;

    output.pixelColor = input.color;
    
    return output;
}