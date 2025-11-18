struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;
	float4					m_cSpecular; //a = power
	float4					m_cEmissive;
};

cbuffer cbCameraInfo : register(b1)
{
	matrix					gmtxView : packoffset(c0);
	matrix					gmtxProjection : packoffset(c4);
	matrix					gmtxInverseView : packoffset(c8);
	float3					gvCameraPosition : packoffset(c12);
};

cbuffer cbGameObjectInfo : register(b2)
{
	matrix					gmtxGameObject : packoffset(c0);
	MATERIAL				gMaterial : packoffset(c4);
	uint					gnTexturesMask : packoffset(c8);
};

cbuffer cbWaterInfo : register(b3)
{
	matrix		gf4x4TextureAnimation : packoffset(c0);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Water Shaders
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
struct VS_WATER_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD0;
};

struct VS_WATER_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD0;
};

#include "Light.hlsl"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//#define _WITH_VERTEX_LIGHTING

#define MATERIAL_ALBEDO_MAP			0x01
#define MATERIAL_SPECULAR_MAP		0x02
#define MATERIAL_NORMAL_MAP			0x04
#define MATERIAL_METALLIC_MAP		0x08
#define MATERIAL_EMISSION_MAP		0x10
#define MATERIAL_DETAIL_ALBEDO_MAP	0x20
#define MATERIAL_DETAIL_NORMAL_MAP	0x40

Texture2D gtxtAlbedoTexture : register(t24);
Texture2D gtxtSpecularTexture : register(t25);
Texture2D gtxtNormalTexture : register(t26);
Texture2D gtxtMetallicTexture : register(t27);
Texture2D gtxtEmissionTexture : register(t28);
Texture2D gtxtDetailAlbedoTexture : register(t29);
Texture2D gtxtDetailNormalTexture : register(t30);

Texture2D gtxtWaterBaseTexture : register(t6);
Texture2D gtxtWaterDetail0Texture : register(t7);
Texture2D gtxtWaterDetail1Texture : register(t8);

SamplerState gssWrap : register(s0);
SamplerState gssClamp : register(s1);
VS_WATER_OUTPUT VSTerrainWater(VS_WATER_INPUT input)
{
    VS_WATER_OUTPUT output;

    // Transform position from model space to world space
    float4 worldPos = mul(float4(input.position, 1.0f), gmtxGameObject);
    
    // Transform position from world space to view space, then to projection space
    output.position = mul(mul(worldPos, gmtxView), gmtxProjection);
    
    // Pass UVs directly to pixel shader
    output.uv = input.uv;

    return output;
}

float4 PSTerrainWater(VS_WATER_OUTPUT input) : SV_TARGET
{
	float2 uv = input.uv;

	//
	uv = mul(float3(input.uv, 1.0f), (float3x3)gf4x4TextureAnimation).xy;

	//
	float4 cBaseTexColor = gtxtWaterBaseTexture.SampleLevel(gssWrap, uv, 0);
	float4 cDetail0TexColor = gtxtWaterDetail0Texture.SampleLevel(gssWrap, uv * 20.0f, 0);
	float4 cDetail1TexColor = gtxtWaterDetail1Texture.SampleLevel(gssWrap, uv * 20.0f, 0);

	//
	float4 cColor = lerp(cBaseTexColor * cDetail0TexColor, cDetail1TexColor.r * 0.5f, 0.35f);
	//cColor.a = 1.0f;
	return(cColor);
}

struct VS_STANDARD_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 bitangent : BITANGENT;
};

struct VS_STANDARD_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float3 normalW : NORMAL;
	float3 tangentW : TANGENT;
	float3 bitangentW : BITANGENT;
	float2 uv : TEXCOORD;
};

VS_STANDARD_OUTPUT VSStandard(VS_STANDARD_INPUT input)
{
    VS_STANDARD_OUTPUT output;


    float4 posW = mul(float4(input.position, 1.0f), gmtxGameObject);
    output.positionW = posW.xyz;

    output.tangentW   = normalize(mul((float3x3)gmtxGameObject, input.tangent));
    output.bitangentW = normalize(mul((float3x3)gmtxGameObject, input.bitangent));
    output.normalW    = normalize(mul((float3x3)gmtxGameObject, input.normal)); //

    
    float3 N = output.normalW;
    float3 T = normalize(output.tangentW - N * dot(output.tangentW, N));
    float3 B = normalize(cross(N, T));   //

    //
    output.tangentW   = T;
    output.bitangentW = B;
    output.normalW    = N;

    output.position = mul(mul(posW, gmtxView), gmtxProjection);
    output.uv = input.uv;
    return output;
}

float4 PSStandard(VS_STANDARD_OUTPUT input) : SV_TARGET
{
	// Initialize cAlbedoColor with the material's diffuse color
	float4 cAlbedoColor = gMaterial.m_cDiffuse; 
	float4 cSpecularColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cNormalColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cMetallicColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cEmissionColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	if (gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtAlbedoTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtSpecularTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtNormalTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtMetallicTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtEmissionTexture.Sample(gssWrap, input.uv);

	float4 cIllumination = float4(1.0f, 1.0f, 1.0f, 1.0f);
	float4 cColor = cAlbedoColor + cSpecularColor + cEmissionColor;
	if (gnTexturesMask & MATERIAL_NORMAL_MAP)
    {
        float3x3 TBN = float3x3(input.tangentW, input.bitangentW, input.normalW);
        float3 vNormalTS = normalize(cNormalColor.rgb * 2.0f - 1.0f);
        float3 normalW = normalize(mul(vNormalTS, TBN));
        float4 cIllumination = Lighting(input.positionW, normalW);
        cColor = lerp(cColor, cIllumination, 0.5f);
    }
    return cColor;
}

float4 PSStandardPlayer(VS_STANDARD_OUTPUT input) : SV_TARGET
{
	float4 c = PSStandard(input); //
	
    c.a = 0.3f;
	
	return c;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SKYBOX_CUBEMAP_INPUT
{
	float3 position : POSITION;
};

struct VS_SKYBOX_CUBEMAP_OUTPUT
{
	float3	positionL : POSITION;
	float4	position : SV_POSITION;
};

VS_SKYBOX_CUBEMAP_OUTPUT VSSkyBox(VS_SKYBOX_CUBEMAP_INPUT input)
{
	VS_SKYBOX_CUBEMAP_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.positionL = input.position;

	return(output);
}

TextureCube gtxtSkyCubeTexture : register(t13);


float4 PSSkyBox(VS_SKYBOX_CUBEMAP_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtSkyCubeTexture.Sample(gssClamp, input.positionL);

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SPRITE_TEXTURED_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
};

struct VS_SPRITE_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

VS_SPRITE_TEXTURED_OUTPUT VSTextured(VS_SPRITE_TEXTURED_INPUT input)
{
	VS_SPRITE_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

/*
float4 PSTextured(VS_SPRITE_TEXTURED_OUTPUT input, uint nPrimitiveID : SV_PrimitiveID) : SV_TARGET
{
	float4 cColor;
	if (nPrimitiveID < 2)
		cColor = gtxtTextures[0].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 4)
		cColor = gtxtTextures[1].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 6)
		cColor = gtxtTextures[2].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 8)
		cColor = gtxtTextures[3].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 10)
		cColor = gtxtTextures[4].Sample(gWrapSamplerState, input.uv);
	else
		cColor = gtxtTextures[5].Sample(gWrapSamplerState, input.uv);
	float4 cColor = gtxtTextures[NonUniformResourceIndex(nPrimitiveID/2)].Sample(gWrapSamplerState, input.uv);

	return(cColor);
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
Texture2D gtxtTerrainTexture : register(t14);
Texture2D gtxtDetailTexture : register(t15);
Texture2D gtxtAlphaTexture : register(t16);
Texture2D gtxtAlphaTextures[] : register(t23);

float4 PSTextured(VS_SPRITE_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTerrainTexture.Sample(gssWrap, input.uv);

	return(cColor);
}

struct VS_TERRAIN_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct VS_TERRAIN_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.color = input.color;
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;

	return(output);
}

float4 PSTerrain(VS_TERRAIN_OUTPUT input) : SV_TARGET
{
	float4 cBaseTexColor = gtxtTerrainTexture.Sample(gssWrap, input.uv0);
	float4 cDetailTexColor = gtxtDetailTexture.Sample(gssWrap, input.uv1);
	//	float fAlpha = gtxtTerrainTexture.Sample(gssWrap, input.uv0);

	float4 cColor = cBaseTexColor * 0.5f + cDetailTexColor * 0.5f;
	//	float4 cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UI SHADERS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Texture2D gtxtUITexture : register(t0);

// VS_SPRITE_TEXTURED_INPUT and VS_SPRITE_TEXTURED_OUTPUT are already defined and are suitable for UI.

VS_SPRITE_TEXTURED_OUTPUT VS_UI(VS_SPRITE_TEXTURED_INPUT input)
{
	VS_SPRITE_TEXTURED_OUTPUT output;

    // For UI, we assume the input position is already in NDC.
    // The C++ code will provide an identity matrix for the world matrix.
	output.position = float4(input.position, 1.0f);
	output.uv = input.uv;

	return(output);
}

float4 PS_UI(VS_SPRITE_TEXTURED_OUTPUT input) : SV_TARGET
{
	return gtxtUITexture.Sample(gssWrap, input.uv);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
// Billboard Shaders
//-------------------------------------------------------------------------------------------------------------------------------------------------

Texture2D gtxtBillboard : register(t17);

//-------------------------------------------------------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------------------------------------------------------
struct VS_BILLBOARD_INPUT
{
	float3 position : POSITION;
};

//-------------------------------------------------------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------------------------------------------------------
struct GS_BILLBOARD_INPUT
{
	float3 position : POSITION;
};

//-------------------------------------------------------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------------------------------------------------------
struct PS_BILLBOARD_INPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

//-------------------------------------------------------------------------------------------------------------------------------------------------
// Vertex Shader:
//-------------------------------------------------------------------------------------------------------------------------------------------------
GS_BILLBOARD_INPUT VSBillboard(VS_BILLBOARD_INPUT input)
{
	GS_BILLBOARD_INPUT output;
	output.position = input.position; //
	return output;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
// Geometry Shader:
//-------------------------------------------------------------------------------------------------------------------------------------------------
[maxvertexcount(4)]
void GSBillboard(point GS_BILLBOARD_INPUT input[1], inout TriangleStream<PS_BILLBOARD_INPUT> outputStream)
{
	float2 size = float2(4.0f, 4.0f);
	
    float3 cameraForward = normalize(gmtxInverseView._31_32_33);
    float3 up = float3(0.0f, 1.0f, 0.0f);
    float3 right = normalize(cross(up, cameraForward));
	
	float3 positions[4];
	positions[0] = input[0].position + (-right * size.x) + (up * size.y); // Top-Left
	positions[1] = input[0].position + (right * size.x) + (up * size.y);  // Top-Right
	positions[2] = input[0].position + (-right * size.x) - (up * size.y); // Bottom-Left
	positions[3] = input[0].position + (right * size.x) - (up * size.y);  // Bottom-Right
	
	float2 uvs[4] =
	{
		float2(0.0f, 0.0f),
		float2(1.0f, 0.0f),
		float2(0.0f, 1.0f),
		float2(1.0f, 1.0f)
	};

	PS_BILLBOARD_INPUT output;
	
	[unroll]
	for (int i = 0; i < 4; i++)
	{
		output.position = float4(positions[i], 1.0f); //
		output.position = mul(output.position, gmtxView);
		output.position = mul(output.position, gmtxProjection);
		output.uv = uvs[i];
		outputStream.Append(output);
	}
	
	outputStream.RestartStrip();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
// Pixel Shader:
//-------------------------------------------------------------------------------------------------------------------------------------------------
float4 PSBillboard(PS_BILLBOARD_INPUT input) : SV_TARGET
{
	float4 color = gtxtBillboard.Sample(gssWrap, input.uv); //
    
    //
	clip(color.a - 0.1f);
	
	return color;
}

//=================================================================================================================================================
// EXPLOSION SHADERS
//=================================================================================================================================================

#define EXP_FRAME_COLS 8
#define EXP_FRAME_ROWS 8

struct VS_GS_INPUT
{
    float3 position : POSITION;
    uint   frame    : TEXCOORD0; // Frame index
};

struct GS_PS_INPUT
{
    float4 position : SV_POSITION;
    float2 uv       : TEXCOORD0;
	uint   frame    : TEXCOORD1;
};

// Vertex Shader: Pass vertex position and frame index to the Geometry Shader
VS_GS_INPUT VS_Explosion(float3 position : POSITION)
{
    VS_GS_INPUT output;
    output.position = mul(float4(position, 1.0f), gmtxGameObject).xyz;
    output.frame = gnTexturesMask; // Re-using gnTexturesMask from cbGameObjectInfo as the frame index
    return output;
}

// Geometry Shader: Generate a quad billboard facing the camera from a single point
[maxvertexcount(4)]
void GS_Explosion(point VS_GS_INPUT input[1], inout TriangleStream<GS_PS_INPUT> outputStream)
{
    float3 up = float3(gmtxView._12, gmtxView._22, gmtxView._32);
    float3 right = float3(gmtxView._11, gmtxView._21, gmtxView._31);

    float halfSize = 20.0f; // Explosion size

    float4 positions[4];
    positions[0] = float4(input[0].position + (-right + up) * halfSize, 1.0f);
    positions[1] = float4(input[0].position + ( right + up) * halfSize, 1.0f);
    positions[2] = float4(input[0].position + (-right - up) * halfSize, 1.0f);
    positions[3] = float4(input[0].position + ( right - up) * halfSize, 1.0f);

    GS_PS_INPUT output;
    
    output.position = mul(positions[0], gmtxView);
    output.position = mul(output.position, gmtxProjection);
    output.uv = float2(0.0f, 0.0f);
	output.frame = input[0].frame;
    outputStream.Append(output);

    output.position = mul(positions[1], gmtxView);
    output.position = mul(output.position, gmtxProjection);
    output.uv = float2(1.0f, 0.0f);
	output.frame = input[0].frame;
    outputStream.Append(output);

    output.position = mul(positions[2], gmtxView);
    output.position = mul(output.position, gmtxProjection);
    output.uv = float2(0.0f, 1.0f);
	output.frame = input[0].frame;
    outputStream.Append(output);

	output.position = mul(positions[3], gmtxView);
    output.position = mul(output.position, gmtxProjection);
    output.uv = float2(1.0f, 1.0f);
	output.frame = input[0].frame;
    outputStream.Append(output);
	
	outputStream.RestartStrip();
}

// Pixel Shader: Calculate the correct UV for the sprite sheet and sample the texture
float4 PS_Explosion(GS_PS_INPUT input) : SV_TARGET
{
    uint frame = input.frame;
    
    float fCellW = 1.0f / EXP_FRAME_COLS;
    float fCellH = 1.0f / EXP_FRAME_ROWS;
    
    uint u_idx = frame % EXP_FRAME_COLS;
    uint v_idx = frame / EXP_FRAME_COLS;
    
    float2 startUV = float2(u_idx * fCellW, v_idx * fCellH);
    
    float2 finalUV = startUV + input.uv * float2(fCellW, fCellH);
    
    float4 color = gtxtAlbedoTexture.Sample(gssWrap, finalUV);
    
    // Discard pixel if alpha is too low to prevent square outlines
    clip(color.a - 0.01f); 
    
    return color;
}


float4 PSMirror(VS_STANDARD_OUTPUT input) : SV_TARGET
{
    float4 cColor = gMaterial.m_cAmbient;
    cColor.a = gMaterial.m_cAmbient.a;
    return cColor;
}