#ifndef FIZZ6_OUTLINE_INCLUDE
#define FIZZ6_OUTLINE_INCLUDE

#include <HLSLSupport.cginc>
#include <UnityCG.cginc>

///////////////////////////////////////////////////////////////////////////////
//                      CBUFFER                                              //
///////////////////////////////////////////////////////////////////////////////

CBUFFER_START(UnityPerMaterial)
    float _OutlineWeight;
    float3 _OutlineColor;
CBUFFER_END

///////////////////////////////////////////////////////////////////////////////
//                      STRUCTS                                              //
///////////////////////////////////////////////////////////////////////////////

struct v2f 
{
    float4 vertex : SV_POSITION;
};

///////////////////////////////////////////////////////////////////////////////
//                      Functions                                            //
///////////////////////////////////////////////////////////////////////////////

v2f vert(const appdata_base v)
{
    v2f o;
    float3 vertex = v.vertex;
    vertex += v.normal * _OutlineWeight;
    o.vertex = UnityObjectToClipPos(vertex);
    return o;
}

fixed3 frag(const v2f i) : SV_Target
{
    return _OutlineColor;
}

#endif
