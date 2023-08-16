Shader "MyCustom/Chapter32_Ocean"
{
    Properties
    {
        [Header(Base Color)]
        _ShallowColor           ("_ShallowColor",               Color)          =   (0.44, 0.95, 0.36, 1.0) 
        _DeepColor              ("_DeepColor",                  Color)          =   (0.0, 0.05, 0.19, 1.0) 
        _FarColor               ("_FarColor",                  Color)           =   (0.0, 0.05, 0.19, 1.0) 
        
        [Header(Densities)]
        _DepthDensity           ("_DepthDensity",               Range(0, 1))    = 0.5
        _DistanceDensity        ("_DistanceDensity",            Range(0, 0.01)) = 0.0018

        [Header(Reflection)]
        _ReflectedContribution  ("_ReflectedContribution",      Range(0, 1))     = 0.5

        [Header(Edge Foam)]
        _EdgeFoamColor          ("_EdgeFoamColor",              Color)          = (1, 1, 1, 1)
        _EdgeFoamDepth          ("_EdgeFoamDepth",              Range(0, 1))    = 0.25

        [Header(Waves)]
        _WaveNormalMap          ("_WaveNormalMap",              2D)             = "bump" {}
        _Wave0Direction         ("_Wave0Direction",             Range(0, 0.5))  = 0.25
        _Wave0Amplitude         ("_Wave0Amplitude",             float)          = 1
        _Wave0Length            ("_Wave0Length",                float)          = 10
        _Wave0Speed             ("_Wave0Speed",                 float)          = 0.25

        _Wave1Direction         ("_Wave1Direction",             Range(0.5, 1))  = 0.75
        _Wave1Amplitude         ("_Wave1Amplitude",             float)          = 1
        _Wave1Length            ("_Wave1Length",                float)          = 10
        _Wave1Speed             ("_Wave1Speed",                 float)          = 0.25

        _Wave1NormalSpeed       ("_Wave1NormalSpeed",           float)          = 0.05
        _Wave1NormalScale       ("_Wave1NormalScale",           float)          = 20

        [Header(Sparkle)]
        _SparkleNormalMap       ("_SparkleNormalMap",           2D)             = "bump" {}
        _SparkleScale           ("_SparkleScale",               float)          = 75
        _SparkleSpeed           ("_SparkleSpeed",               float)          = 0.025
        _SparkleColor           ("_SparkleColor",               Color)          = (1, 1, 1, 1)
        _SparkleExponent        ("_SparkleExponent",            float)          = 3
        _SparkleAmplitude       ("_SparkleAmplitude",           float)          = 5

        [Header(Sun Specular)]
        _SpecularColor          ("_SpecularColor",              Color)          = (1, 1, 1, 1)
        _SpecularPower          ("_SpecularPower",              float)          = 10
        _SpecularAmplitude      ("_SpeculaAmplitude",           float)          = 1

        [Header(SSS)]
        _SSSColor               ("_SSSColor",                   Color)          = (1, 1, 1, 1)
    
        [Header(Foam)]
        _FoamTexture            ("_FoamTexture",                2D)             = "black" {}
        _FoamNoiseScale         ("_FoamNoiseScale",             float)          = 0.5
        _FoamScale              ("_FoamScale",                  float)          = 1
        _FoamSpeed              ("_FoamSpeed",                  float)          = 0.1
        _FoamAmplitude          ("_FoamAmplitude",              float)          = 1

        [Header(Shadow Map)]
        _MaxShadowMapDistance   ("_MaxShadowMapDistance",       float)          = 50
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        // 这里是用来计算 _CameraDepthTexture的
        Tags    // Rendering Order - Queue tag 只能写在这里
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }

        GrabPass
        {
            "_GrabTexture"
        }

        Pass
        {
            Tags { "LightMode"="Always" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #define PI 3.1415926

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv               : TEXCOORD0;
                float4 grabPos          : TEXCOORD1;
                float3 worldPos         : TEXCOORD2;       
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
            };

            sampler2D _CameraDepthTexture;
            sampler2D _GrabTexture;
            sampler2D _DirectionalShadowMap;

            float4 _ShallowColor;
            float4 _DeepColor;
            float4 _FarColor;
            float _DepthDensity;
            float _DistanceDensity;

            // Waves
            sampler2D _WaveNormalMap;
            float _Wave0Direction;
            float _Wave0Amplitude;
            float _Wave0Length;
            float _Wave0Speed;

            float _Wave1Direction;
            float _Wave1Amplitude;
            float _Wave1Length;
            float _Wave1Speed;

            float _Wave1NormalSpeed;
            float _Wave1NormalScale;

            // Reflection
            float _ReflectedContribution;

            // Edge Foam
            float4 _EdgeFoamColor;
            float _EdgeFoamDepth;

            // Sparkle
            sampler2D _SparkleNormalMap;
            float _SparkleScale;
            float _SparkleSpeed;
            float3 _SparkleColor;
            float _SparkleExponent;
            float _SparkleAmplitude;

            // Sun Specular
            float3 _SpecularColor;
            float _SpecularPower;
            float _SpecularAmplitude;

            // SSS
            float3 _SSSColor;

            // Foam
            sampler2D _FoamTexture;
            float _FoamNoiseScale;
            float _FoamScale;
            float _FoamSpeed;
            float _FoamAmplitude;

            // Shadow Map
            float _MaxShadowMapDistance;

            float _wave(float2 position, float2 direction, float waveLength, float amplitude, float speed)
            {
                float d = PI * dot(position, direction) / waveLength;
                float phase = speed * _Time.y;
                float wave = amplitude * sin(d + phase);
                return wave;
            }

            float _calculateWaveHeight(float2 position)
            {
                float2 dir0 = float2(cos(PI * _Wave0Direction), sin(PI * _Wave0Direction));
                float wave0 = _wave(position, dir0, _Wave0Length, _Wave0Amplitude, _Wave0Speed);

                float2 dir1 = float2(cos(PI * _Wave1Direction), sin(PI * _Wave1Direction));
                float wave1 = _wave(position, dir1, _Wave1Length, _Wave1Amplitude, _Wave1Speed);

                return wave0 + wave1;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                //o.worldPos.y += _calculateWaveHeight(o.worldPos.xz);
                o.pos = mul(UNITY_MATRIX_VP, float4(o.worldPos, 1));
                o.grabPos = ComputeGrabScreenPos(o.pos);

                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }

            float3 _refractedColor(v2f i, out float2 screenCoord)
            {
                screenCoord = i.grabPos.xy / i.grabPos.w;
                float3 color = tex2D(_GrabTexture, screenCoord).rgb * _ShallowColor;
                return color;
            }
            
            float3 _baseColor(v2f i, float3 refractedColor, float2 screenCoord, float shadowMask, out float biasDepth, out float distanceMask)
            {
                float depth = tex2D(_CameraDepthTexture, screenCoord).r;
                biasDepth = abs(LinearEyeDepth(depth) - LinearEyeDepth(i.pos.z));

                float transmittance = exp(-_DepthDensity * biasDepth);

                float3 color = lerp(_DeepColor, refractedColor, transmittance);

                float dist = length(i.worldPos - _WorldSpaceCameraPos.xyz);
                distanceMask = exp(-_DistanceDensity * dist);
                color = lerp(_FarColor, color, distanceMask);

                color *= max(shadowMask, 0.5);
                return color;
            }

            float3x3 _tbn(float2 worldPos, float d)
            {
                // tangent, binormal在平面的简易算法
                //float3 tangent = float3(0, 0, 1);
                //float3 binormal = float3(1, 0, 0);
                //float3 normal = normalize(cross(binormal, tangent));

                float waveHeight = _calculateWaveHeight(worldPos);
                float waveHeightDX = _calculateWaveHeight(worldPos - float2(d, 0));
                float waveHeightDZ = _calculateWaveHeight(worldPos - float2(0, d));

                // 使用worldPos来计算平面上的tangent和binormal
                float3 tangent = normalize(float3(0, waveHeight - waveHeightDX, d));
                float3 binormal = normalize(float3(d, waveHeight - waveHeightDZ, 0));
                float3 normal = normalize(cross(binormal, tangent));

                return float3x3(tangent, binormal, normal);
            }

            float2 _panner(float2 uv, float2 direction, float speed)
            {
                return uv + normalize(direction) * _Time.y * speed;
            }

            float3 _motion4Ways(sampler2D tex, float2 uv, float2 offset[4], float4 scale, float speed, int texType)
            {
                float2 uv0 = _panner((uv + offset[0]) * scale.x, float2(1, 1), speed);
                float2 uv1 = _panner((uv + offset[1]) * scale.y, float2(1, -1), speed);
                float2 uv2 = _panner((uv + offset[2]) * scale.z, float2(-1, -1), speed);
                float2 uv3 = _panner((uv + offset[3]) * scale.w, float2(-1, 1), speed);

                if (texType >= 0)
                {
                    float3 sample0 = UnpackNormal(tex2D(tex, uv0)).rgb;  
                    float3 sample1 = UnpackNormal(tex2D(tex, uv1)).rgb;  
                    float3 sample2 = UnpackNormal(tex2D(tex, uv2)).rgb;  
                    float3 sample3 = UnpackNormal(tex2D(tex, uv3)).rgb;  

                    if (texType == 0)
                        return normalize(sample0 + sample1 + sample2 + sample3);
                    else
                    {
                        float3 normal0 = float3(sample0.x, sample1.y, 1);
                        float3 normal1 = float3(sample2.x, sample3.y, 1);

                        return normalize(float3((normal0 + normal1).xy, (normal0 * normal1).z));
                    }
                }
                else
                {
                    float3 sample0 = tex2D(tex, uv0).rgb;  
                    float3 sample1 = tex2D(tex, uv1).rgb;  
                    float3 sample2 = tex2D(tex, uv2).rgb;  
                    float3 sample3 = tex2D(tex, uv3).rgb;  

                    return (sample0 + sample1 + sample2 + sample3) / 4.0;
                }
            }

            float3 _reflectedColor(v2f i, float shadowMask, float distanceMask, out float3 normalTS, out float3 viewDirWS, out float3 viewReflection)
            {
                //float3 normalTS = UnpackNormal(tex2D(_WaveNormalMap, i.uv));
                float2 offset[4] = {float2(0, 0),
                                    float2(0.418, 0.355),
                                    float2(0.865, 0.148),
                                    float2(0.651, 0.752)};
                normalTS = _motion4Ways(_WaveNormalMap, 
                                        i.worldPos.xz / _Wave1NormalScale, 
                                        offset,
                                        float4(1, 1, 1, 1),
                                        _Wave1NormalSpeed,
                                        0);
                float3x3 tbn = _tbn(i.worldPos.xz, 0.01);

                float3 normalWS = mul(normalTS, tbn);
                viewDirWS = normalize(i.worldPos - _WorldSpaceCameraPos);
                float fresnelMask = pow(1 + dot(normalWS, -viewDirWS), 5) * _ReflectedContribution;

                viewReflection = reflect(viewDirWS, normalWS);
                float3 color = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, viewReflection);
                //color *= fresnelMask;

                //color *= shadowMask * distanceMask;
                return color;
            }

            float3 _edgeFoamColor(float biasDepth, float shadowMask)
            {
                float edgeFoamMask = exp(-biasDepth / _EdgeFoamDepth);
                edgeFoamMask = round(edgeFoamMask);
                float3 color = lerp(0, _EdgeFoamColor, edgeFoamMask);

                color *= lerp(UNITY_LIGHTMODEL_AMBIENT.xyz, 1, shadowMask);
                return color;
            }

            float3 _sparkleColor(v2f i, float shadowMask, float distanceMask)
            {
                float2 offset[4] = {float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0)};
                float3 sparkle0 = _motion4Ways(_SparkleNormalMap, 
                                                i.worldPos.xz / _SparkleScale, 
                                                offset, 
                                                float4(1, 2, 3, 4),
                                                _SparkleSpeed,
                                                1);

                float3 sparkle1 = _motion4Ways(_SparkleNormalMap, 
                                                i.worldPos.xz / _SparkleScale, 
                                                offset, 
                                                float4(1, 0.5, 2.5, 2),
                                                _SparkleSpeed,
                                                1);
                
                float sparkleMask = dot(sparkle0, sparkle1) * saturate(_SparkleAmplitude * sqrt(saturate(dot(sparkle0.x, sparkle1.x))));
                sparkleMask = pow(sparkleMask, _SparkleExponent);
                sparkleMask = ceil(sparkleMask);

                float3 color = lerp(0, _SparkleColor, sparkleMask) * max(shadowMask, 0.1) * distanceMask;
                
                return color;
            }

            float3 _specularColor(float3 viewReflection, float shadowMask)
            {
                float mask = saturate(dot(viewReflection, _WorldSpaceLightPos0));
                mask = pow(mask, _SpecularPower);
                mask = round(mask);
                mask *= _SpecularAmplitude;

                float3 color = lerp(0, _SpecularColor, mask) * shadowMask;
                return mask;
            }

            float3 _sssColor(v2f i, float3 viewDirWS)
            {
                float mask = saturate(dot(viewDirWS, _WorldSpaceLightPos0));

                float waveHeight = saturate(_calculateWaveHeight(i.worldPos.xz));
                float3 color = _SSSColor * mask * waveHeight;
                return color;
            }

            float3 _foamColor(v2f i, float3 normalTS, float shadowMask, float distanceMask)
            {
                float2 uv = i.worldPos.xz / _FoamScale + (_FoamNoiseScale * normalTS.xz);

                float2 offset[4] = {float2(0, 0),
                                    float2(0.418, 0.355),
                                    float2(0.865, 0.148),
                                    float2(0.651, 0.752)};

                float3 color = _motion4Ways(_FoamTexture, 
                                uv, 
                                offset, 
                                float4(1, 1, 1, 1),
                                _FoamSpeed,
                                -1);

                color *= _FoamAmplitude * max(shadowMask, 0.2) * distanceMask;

                return color;
            }

            float _shadowMap(float3 worldPos)
            {
                float dist = length(worldPos - _WorldSpaceCameraPos.xyz);

                if (dist > _MaxShadowMapDistance)
                    return 1;

                float4 near = float4(dist >= _LightSplitsNear);
                float4 far = float4(dist < _LightSplitsFar);
                float4 weights = near * far;

                float4 sc0 = mul(unity_WorldToShadow[0], float4(worldPos, 1)) * weights.x;
                float4 sc1 = mul(unity_WorldToShadow[1], float4(worldPos, 1)) * weights.y;
                float4 sc2 = mul(unity_WorldToShadow[2], float4(worldPos, 1)) * weights.z;
                float4 sc3 = mul(unity_WorldToShadow[3], float4(worldPos, 1)) * weights.w;

                float4 shadowCoord = sc0 + sc1 + sc2 + sc3;
                return tex2Dproj(_DirectionalShadowMap, shadowCoord) < shadowCoord.z / shadowCoord.w;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float shadowMask = _shadowMap(i.worldPos);

                float2 screenCoord;

                float3 refractedColor = _refractedColor(i, screenCoord);

                float biasDepth;
                float distanceMask;
                float3 baseColor = _baseColor(i, refractedColor, screenCoord, shadowMask, biasDepth, distanceMask);
                
                float3 normalTS;
                float3 viewDirWS;
                float3 viewReflection;
                float3 reflectedColor = _reflectedColor(i, shadowMask, distanceMask, normalTS, viewDirWS, viewReflection);

                float3 edgeFoamColor = _edgeFoamColor(biasDepth, shadowMask);
                float3 sparkleColor = _sparkleColor(i, shadowMask, distanceMask);
                float3 specularColor = _specularColor(viewReflection, shadowMask);
                float3 sssColor = _sssColor(i, viewDirWS);
                float3 foamColor = _foamColor(i, normalTS, shadowMask, distanceMask);

                float3 finalColor = baseColor + reflectedColor + edgeFoamColor + sparkleColor + specularColor + sssColor + foamColor;
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return float4(reflectedColor, 1);
            }
            ENDCG
        }
    }
}
