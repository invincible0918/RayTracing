Shader "MyCustom/MyPBR"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertBase
            #pragma fragment _fragForwardBaseInternal
            #include "UnityStandardCoreForward.cginc"

            inline FragmentCommonData _MetallicSetup (float4 i_tex)
            {
                half2 metallicGloss = MetallicGloss(i_tex.xy);
                half metallic = metallicGloss.x;
                half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m.

                half oneMinusReflectivity;
                half3 specColor;
                half3 diffColor = DiffuseAndSpecularFromMetallic (Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

                FragmentCommonData o = (FragmentCommonData)0;
                o.diffColor = diffColor;
                o.specColor = specColor;
                o.oneMinusReflectivity = oneMinusReflectivity;
                o.smoothness = smoothness;
                return o;
            }

            inline FragmentCommonData _FragmentSetup (inout float4 i_tex, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)
            {
                i_tex = Parallax(i_tex, i_viewDirForParallax);

                half alpha = Alpha(i_tex.xy);
                #if defined(_ALPHATEST_ON)
                    clip (alpha - _Cutoff);
                #endif

                FragmentCommonData o = _MetallicSetup (i_tex);
                o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld);
                o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
                o.posWorld = i_posWorld;

                // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
                o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
                return o;
            }

            half4 _BRDF1_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
                float3 normal, float3 viewDir,
                UnityLight light, UnityIndirect gi)
            {
                float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
                float3 halfDir = Unity_SafeNormalize (float3(light.dir) + viewDir);

            // NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
            // In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
            // but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
            // Following define allow to control this. Set it to 0 if ALU is critical on your platform.
            // This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
            // Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
            #define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

            #if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
                // The amount we shift the normal toward the view vector is defined by the dot product.
                half shiftAmount = dot(normal, viewDir);
                normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
                // A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
                //normal = normalize(normal);

                half nv = saturate(dot(normal, viewDir)); // TODO: this saturate should no be necessary here
            #else
                half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
            #endif

                half nl = saturate(dot(normal, light.dir));
                float nh = saturate(dot(normal, halfDir));

                half lv = saturate(dot(light.dir, viewDir));
                half lh = saturate(dot(light.dir, halfDir));

                // Diffuse term
                half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

                // Specular term
                // HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
                // BUT 1) that will make shader look significantly darker than Legacy ones
                // and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
                float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
            #if UNITY_BRDF_GGX
                // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
                roughness = max(roughness, 0.002);
                half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
                float D = GGXTerm (nh, roughness);
            #else
                // Legacy
                half V = SmithBeckmannVisibilityTerm (nl, nv, roughness);
                half D = NDFBlinnPhongNormalizedTerm (nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
            #endif

                half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later

            #   ifdef UNITY_COLORSPACE_GAMMA
                    specularTerm = sqrt(max(1e-4h, specularTerm));
            #   endif

                // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
                specularTerm = max(0, specularTerm * nl);
            #if defined(_SPECULARHIGHLIGHTS_OFF)
                specularTerm = 0.0;
            #endif

                // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
                half surfaceReduction;
            #   ifdef UNITY_COLORSPACE_GAMMA
                    surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
            #   else
                    surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
            #   endif

                // To provide true Lambert lighting, we need to be able to kill specular completely.
                specularTerm *= any(specColor) ? 1.0 : 0.0;

                half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
                half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                                + specularTerm * light.color * FresnelTerm (specColor, lh)
                                + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv);
                return half4(color, 1);
            }


            half4 _fragForwardBaseInternal (VertexOutputForwardBase i) : SV_Target
            {
                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

                FragmentCommonData s = _FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i));

                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                UnityLight mainLight = MainLight ();
                UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

                half occlusion = Occlusion(i.tex.xy);
                UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

                half4 c = _BRDF1_Unity_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
                c.rgb += Emission(i.tex.xy);

                //c.rgb = s.diffColor; 

                UNITY_APPLY_FOG(i.fogCoord, c.rgb);
                return OutputForward (c, s.alpha);
            }


            ENDCG
        }
    }


    FallBack "VertexLit"
    CustomEditor "StandardShaderGUI"
}
