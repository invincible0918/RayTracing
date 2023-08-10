Shader "MyCustom/Denoise"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        //Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define SAMPLES 10  // HIGHER = NICER = SLOWER
            #define DISTRIBUTION_BIAS 0.6 // between 0. and 1.
            #define PIXEL_MULTIPLIER  1.5 // between 1. and 3. (keep low)
            #define INVERSE_HUE_TOLERANCE 20.0 // (2. - 30.)

            #define GOLDEN_ANGLE 2.3999632 //3PI-sqrt(5)PI
            #define pow(a,b) pow(max(a, 0.), b) // @morimea

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            float2x2 rotationMatrix = float2x2(cos(GOLDEN_ANGLE), sin(GOLDEN_ANGLE), -sin(GOLDEN_ANGLE), cos(GOLDEN_ANGLE));

            float3 sirBirdDenoise(float2 uv) 
            {
                float3 denoisedColor = 0;

                const float sampleRadius = sqrt(float(SAMPLES));
                const float sampleTrueRadius = 0.5 / (sampleRadius * sampleRadius);
                float2        samplePixel = _MainTex_TexelSize.xy;
                float3        sampleCenter = tex2D(_MainTex, uv).rgb;
                float3        sampleCenterNorm = normalize(sampleCenter);
                float       sampleCenterSat = length(sampleCenter);

                float  influenceSum = 0.0;
                float brightnessSum = 0.0;

                float2 pixelRotated = float2(0., 1.);

                for (float x = 0.0; x <= float(SAMPLES); x++) 
                {
                    pixelRotated = mul(pixelRotated, rotationMatrix);

                    float2 pixelOffset = 0.001*pixelRotated/* * sqrt(x) * 0.5*/;
                    float pixelInfluence = 1.0 - sampleTrueRadius * pow(dot(pixelOffset, pixelOffset), DISTRIBUTION_BIAS);
                    pixelOffset *= _MainTex_TexelSize.xy;

                    float3 thisDenoisedColor = tex2D(_MainTex, uv + pixelOffset).rgb;

                    pixelInfluence *= pixelInfluence * pixelInfluence;
                    /*
                        HUE + SATURATION FILTER
                    */
                    pixelInfluence *=
                        pow(0.5 + 0.5 * dot(sampleCenterNorm, normalize(thisDenoisedColor)), INVERSE_HUE_TOLERANCE)
                        * pow(1.0 - abs(length(thisDenoisedColor) - length(sampleCenterSat)), 8.);

                    influenceSum += pixelInfluence;
                    denoisedColor += thisDenoisedColor/* * pixelInfluence*/;
                }

                return denoisedColor / (SAMPLES+1);
                //return denoisedColor / influenceSum;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 denoisedColor = sirBirdDenoise(i.uv);
                return float4(denoisedColor, 1);
            }
            ENDCG
        }
    }
}
