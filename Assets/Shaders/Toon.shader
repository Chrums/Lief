/*
This is the name of the Shader in the inspector.
You can set directory hierarchy using forward slashes,
like shown here.
*/
Shader "Fizz6/Toon"
{
    /*
    The properties block enables you to edit and save the defined
    Material properties.
    If you don't define anything here, you can still set properties 
    by code, but you can't edit properties from the inspector, and
    changes don't persist between sessions.
    */
    Properties
    {
        [MainTexture] _MainTex ("Main Texture", 2D) = "white" {}
        [MainColor] _Color ("Color", Color) = (1.0, 1.0, 1.0)
        _Buckets ("Buckets", Int) = 3
        _Roughness ("Roughness", Float) = 16.0
        _Ambient ("Ambient", Color) = (1.0, 1.0, 1.0)
        _OutlineWeight ("Outline Weight", Float) = 4.0
        _OutlineColor ("Outline Color", Color) = (0.0, 0.0, 0.0)
    }


    /*
    SubShaders let you define settings and programs that can vary
    depending on hardware, render pipeline, and runtime settings.
    
    This is a more complex topic, but it enables you to write
    shaders that can easily work between different render pipelines.
    */

    SubShader
    {

        /* 
        We need to make sure the Tags includes our RenderPipeline 
        so that this shader works properly.
        */

        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        /*
        These are Shader Commands that control 
        GPU-side rendering properties.
        */

        Cull Back
        ZWrite On
        ZTest LEqual
        ZClip Off

        Pass
        {
            /* 
            The lightmode tag is extremely important.
            Unity sets up and runs render passes.
            These render passes render objects depending on the
            included LightMode tags. 
            
            e.g., "Render only UniversalForwardOnly in this pass".
            
            Our other LightModes (ShadowCaster, DepthOnly, DepthNormalsOnly)
            are automatically queued up and rendered by Unity during
            the appropriate render pass.
            */

            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForwardOnly"
            }


            HLSLPROGRAM
            // These #pragma directives make fog and Decal rendering work.
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

            // These #pragma directives set up Main Light Shadows.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            // These #pragma directives define the function names
            // for our Vertex and Fragment stage functions
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Toon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }


            HLSLPROGRAM
            // This define lets us take an alternate path 
            // when we get the Clipspace Position during the Vertex stage.
            #define SHADOW_CASTER_PASS

            #pragma vertex Vertex

            // In this case, we want to use the FragmentDepthOnly
            // function instead of the Fragment function we 
            // used in the ForwardLit pass.
            #pragma fragment FragmentDepthOnly

            #include "Toon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }


            HLSLPROGRAM
            #pragma vertex Vertex

            // Our DepthOnly Pass and ShadowCaster pass
            // both use the FragmentDepthOnly function
            #pragma fragment FragmentDepthOnly

            #include "Toon.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormalsOnly"
            Tags
            {
                "LightMode" = "DepthNormalsOnly"
            }


            HLSLPROGRAM
            #pragma vertex Vertex

            // And our DepthNormalsOnly pass uses our
            // Fragment function named FragmentDepthNormalsOnly.
            #pragma fragment FragmentDepthNormalsOnly

            #include "Toon.hlsl"
            ENDHLSL
        }

        Pass
        {            
            Tags
            {
                "RenderType" = "Opaque"
                "RenderPipeline" = "UniversalPipeline"
            }
            
            Cull Front
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
         
            #include "Outline.hlsl"
            ENDCG
        }

//        Pass
//        {            
//            Tags
//            {
//                "RenderType" = "Opaque"
//                "RenderPipeline" = "UniversalPipeline"
//            }
//            
//            Cull Front
//            
//            CGPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//            #include "UnityCG.cginc"
//
//            uniform fixed4 _OutlineColor;
//            uniform fixed4 _OutlineWeight;
//         
//            struct v2f {
//                float4 vertex : SV_POSITION;
//            };
//            
//            v2f vert (appdata_base v)
//            {
//                v2f o;
//                float3 vertex = v.vertex;
//                vertex += v.normal * _OutlineWeight;
//                // float3 position = v.vertex.xyz + v.normal * _OutlineWeight;
//                o.vertex = UnityObjectToClipPos(vertex);
//                return o;
//            }
//
//            fixed4 frag (v2f i) : SV_Target
//            {
//                return fixed4(0, 0, 0, 1);
//            }
//            
//            ENDCG
//        }
    }
}