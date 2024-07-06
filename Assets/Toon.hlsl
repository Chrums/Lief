#ifndef FIZZ6_TOON_INCLUDE
#define FIZZ6_TOON_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
// See ShaderVariablesFunctions.hlsl in com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl
///////////////////////////////////////////////////////////////////////////////
//                      CBUFFER                                              //
///////////////////////////////////////////////////////////////////////////////
/*
Unity URP requires us to set up a CBUFFER
(or "Constant Buffer") of Constant Variables.
These should be the same variables we set up 
in the Properties.
This CBUFFER is REQUIRED for Unity
to correctly handle per-material changes
as well as batching / instancing.
Don't skip it :)
*/
CBUFFER_START(UnityPerMaterial)
    TEXTURE2D(_ColorMap);
    SAMPLER(sampler_ColorMap);
    float4 _ColorMap_ST;
    float3 _Color;
    uint _Buckets;
    float _Roughness;
    float3 _Ambient;
CBUFFER_END

///////////////////////////////////////////////////////////////////////////////
//                      STRUCTS                                              //
///////////////////////////////////////////////////////////////////////////////
/*
Our attributes struct is simple.
It contains the Object-Space Position
and Normal Direction as well as the 
UV0 coordinates for the mesh.
The Attributes struct is passed 
from the GPU to the Vertex function.
*/
struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;

    // This line is required for VR SPI to work.
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

/*
The Varyings struct is also straightforward.
It contains the Clip Space Position, the UV, and 
the World-Space Normals.
The Varyings struct is passed from the Vertex
function to the Fragment function.
*/
struct Varyings
{
    float4 positionHCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float3 viewDirectionWS : TEXCOORD3;

    // This line is required for VR SPI to work.
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

///////////////////////////////////////////////////////////////////////////////
//                      Common Lighting Transforms                           //
///////////////////////////////////////////////////////////////////////////////
// This is a global variable, Unity sets it for us.
float3 _LightDirection;
/*
This is a simple lighting transformation.
Normally, we just return the WorldToHClip position.
During the Shadow Pass, we want to make sure that Shadow Bias is baked 
in to the shadow map. To accomplish this, we use the ApplyShadowBias
method to push the world-space positions in their normal direction by the bias amount.
We define SHADOW_CASTER_PASS during the setup for the Shadow Caster pass.
*/
float4 GetClipSpacePosition(float3 positionWS, float3 normalWS)
{
    #if defined(SHADOW_CASTER_PASS)
           float4 positionHCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
           
    #if UNITY_REVERSED_Z
               positionHCS.z = min(positionHCS.z, positionHCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
               positionHCS.z = max(positionHCS.z, positionHCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
           
           return positionHCS;
    #endif

    return TransformWorldToHClip(positionWS);
}

/*
These two functions give us the shadow coordinates 
depending on whether screen shadows are enabled or not.
We have two methods here, one with two args (positionWS
and positionHCS), and one with just positionWS.
The two-arg method is faster when you have 
already calculated the positionHCS variable.
*/
float4 GetMainLightShadowCoord(float3 positionWS, float4 positionHCS)
{
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
           return ComputeScreenPos(positionHCS);
    #else
    return TransformWorldToShadowCoord(positionWS);
    #endif
}

float4 GetMainLightShadowCoord(float3 PositionWS)
{
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
           float4 clipPos = TransformWorldToHClip(PositionWS);
           return ComputeScreenPos(clipPos);
    #else
    return TransformWorldToShadowCoord(PositionWS);
    #endif
}

/*
This method gives us the main light as an out parameter.
The Light struct is defined in 
"Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl",
so you can reference it there for more details on its fields.
This version of the GetMainLight method doesn't account for Light Cookies.
To account for Light cookies, you need to add the following line to your shader pass:
#pragma multi_compile _ _LIGHT_COOKIES
and also call a different GetMainLight method:
GetMainLight(float4 shadowCoord, float3 positionWS, half4 shadowMask)
*/
Light GetMainLightData(float3 PositionWS)
{
    float4 shadowCoord = GetMainLightShadowCoord(PositionWS);
    return GetMainLight(shadowCoord);
}

///////////////////////////////////////////////////////////////////////////////
//                      Functions                                            //
///////////////////////////////////////////////////////////////////////////////
/*
The Vertex function is responsible 
for generating and manipulating the 
data for each vertex of the mesh.
*/
Varyings Vertex(Attributes IN)
{
    Varyings OUT = (Varyings)0;

    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);


    // Set up each field of the Varyings struct, then return it.
    OUT.positionWS = mul(unity_ObjectToWorld, IN.positionOS).xyz;
    OUT.viewDirectionWS = normalize(GetWorldSpaceViewDir(OUT.positionWS));
    OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
    OUT.positionHCS = GetClipSpacePosition(OUT.positionWS, OUT.normalWS);
    OUT.uv = TRANSFORM_TEX(IN.uv, _ColorMap);

    return OUT;
}

/*
The FragmentDepthOnly function is responsible 
for handling per-pixel shading during the 
DepthOnly and ShadowCaster passes.
*/
float FragmentDepthOnly(Varyings IN) : SV_Target
{
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    return 0;
}

/*
The FragmentDepthNormalsOnly function is responsible 
for handling per-pixel shading during the 
DepthNormalsOnly pass. This pass is less common, but
can be required by some post-process effects such as SSAO.
*/
float4 FragmentDepthNormalsOnly(Varyings IN) : SV_Target
{
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    return float4(normalize(IN.normalWS), 0);
}

/*
The Fragment function is responsible 
for handling per-pixel shading during the Forward 
rendering pass. We use the ForwardOnly pass, so this works
by default in both Forward and Deferred paths.
*/
float3 Fragment(Varyings IN) : SV_Target
{
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    IN.normalWS = normalize(IN.normalWS);
    IN.viewDirectionWS = normalize(IN.viewDirectionWS);

    const float smooth_step = 0.01f;
    // Required to have at least 2 buckets
    const int buckets = max(_Buckets, 2);
    
    const Light light = GetMainLightData(IN.positionWS);
    const float normal_dot_light = dot(IN.normalWS, light.direction);
    const float light_multiplier = (normal_dot_light + 1.0f) / 2.0f;
    const int light_index = floor(light_multiplier * buckets);
    
    const float shadows_multiplier = 1.0f - light.shadowAttenuation;
    const int shadows_index = floor(shadows_multiplier * buckets);

    const int index = clamp(light_index - shadows_index, 0, buckets);
    const float directional_multiplier = index / (1.0f * buckets);
    const float3 directional_lighting = directional_multiplier * light.color;

    const float3 half_vector = normalize(light.direction + IN.viewDirectionWS);
    const float normal_dot_half = max(dot(IN.normalWS, half_vector), 0.0f);
    const float specular = pow(normal_dot_half, _Roughness * _Roughness) * directional_multiplier;
    const float specular_multiplier = smoothstep(smooth_step, smooth_step * 2.0f, specular);
    const float3 specular_lightning = specular_multiplier * light.color;

    const float normal_dot_view = max(dot(IN.normalWS, IN.viewDirectionWS), 0.0f);
    const float rim = pow(1.0f - normal_dot_view, 16.0f) * directional_multiplier;
    const float rim_multiplier = smoothstep(smooth_step, smooth_step * 2.0f, rim);
    const float3 rim_lighting = rim_multiplier * light.color;

    const float3 surface_color = _Color * SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, IN.uv);
    const float3 lighting = float3(0.0f, 0.0f, 0.0f) + _Ambient + directional_lighting + specular_lightning + rim_lighting;
    return surface_color * lighting;
}

#endif
