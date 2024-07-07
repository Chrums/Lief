#ifndef FIZZ6_TOON_INCLUDE
#define FIZZ6_TOON_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
// See ShaderVariablesFunctions.hlsl in com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl

///////////////////////////////////////////////////////////////////////////////
//                      CBUFFER                                              //
///////////////////////////////////////////////////////////////////////////////

CBUFFER_START(UnityPerMaterial)
    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    float4 _MainTex_ST;
    float3 _Color;
    uint _Buckets;
    float _Roughness;
    float3 _Ambient;
CBUFFER_END

///////////////////////////////////////////////////////////////////////////////
//                      STRUCTS                                              //
///////////////////////////////////////////////////////////////////////////////

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;

    // This line is required for VR SPI to work.
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

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

// This is a global variable
// Unity sets it for us
const float3 _LightDirection;

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

Light GetMainLightData(float3 PositionWS)
{
    float4 shadowCoord = GetMainLightShadowCoord(PositionWS);
    return GetMainLight(shadowCoord);
}

///////////////////////////////////////////////////////////////////////////////
//                      Functions                                            //
///////////////////////////////////////////////////////////////////////////////

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
    OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

    return OUT;
}

float FragmentDepthOnly(Varyings IN) : SV_Target
{
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    return 0;
}

float4 FragmentDepthNormalsOnly(Varyings IN) : SV_Target
{
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    return float4(normalize(IN.normalWS), 0);
}

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

    const float3 surface_color = _Color * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
    const float3 lighting = float3(0.0f, 0.0f, 0.0f) + _Ambient + directional_lighting + specular_lightning + rim_lighting;
    return surface_color * lighting;
}

#endif
