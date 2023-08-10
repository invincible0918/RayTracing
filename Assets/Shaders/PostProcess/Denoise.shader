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

            #define SAMPLES 80  // HIGHER = NICER = SLOWER
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

            float2 rotation(float2 uv)
            {
                //uv -= 0.5;
                float s = sin(GOLDEN_ANGLE/** (3.1415926f/180.0f)*/);
                float c = cos(GOLDEN_ANGLE/** (3.1415926f/180.0f)*/);
                float2x2 rotationMatrix = float2x2(cos(GOLDEN_ANGLE), sin(GOLDEN_ANGLE), -sin(GOLDEN_ANGLE), cos(GOLDEN_ANGLE));
                //rotationMatrix *= 0.5;
                //rotationMatrix += 0.5;
                //rotationMatrix = rotationMatrix * 2 - 1;
                uv.xy = mul(uv, rotationMatrix);
                //uv += 0.5;
                return uv;
            }

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
                    pixelRotated = rotation(pixelRotated);

                    float2 pixelOffset = PIXEL_MULTIPLIER * pixelRotated * sqrt(x) * 0.5;
                    float pixelInfluence = 1.0 - sampleTrueRadius * pow(dot(pixelOffset, pixelOffset), DISTRIBUTION_BIAS);
                    pixelOffset *= samplePixel;

                    float3 thisDenoisedColor = tex2D(_MainTex, uv + pixelOffset).rgb;

                    //pixelInfluence *= pixelInfluence * pixelInfluence;
                    /*
                        HUE + SATURATION FILTER
                    */
                    pixelInfluence *=
                        pow(0.5 + 0.5 * dot(sampleCenterNorm, normalize(thisDenoisedColor)), INVERSE_HUE_TOLERANCE)
                        * pow(1.0 - abs(length(thisDenoisedColor) - length(sampleCenterSat)), 8.);

                    influenceSum += pixelInfluence;
                    denoisedColor += thisDenoisedColor * pixelInfluence;
                }

                //return denoisedColor / (SAMPLES+1);
                return denoisedColor / influenceSum;
            }

            #define INV_SQRT_OF_2PI 0.39894228040143267793994605993439  // 1.0/SQRT_OF_2PI
            #define INV_PI 0.31830988618379067153776752674503

            //  smartDeNoise - parameters
            //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            //
            //  sampler2D tex     - sampler image / texture
            //  float2 uv           - actual fragment coord
            //  float sigma  >  0 - sigma Standard Deviation
            //  float kSigma >= 0 - sigma coefficient 
            //      kSigma * sigma  -->  radius of the circular kernel
            //  float threshold   - edge sharpening threshold 

            float4 smartDeNoise(float2 uv, float sigma, float kSigma, float threshold)
            {
                float radius = round(kSigma*sigma);
                float radQ = radius * radius;
    
                float invSigmaQx2 = .5 / (sigma * sigma);      // 1.0 / (sigma^2 * 2.0)
                float invSigmaQx2PI = INV_PI * invSigmaQx2;    // 1.0 / (sqrt(PI) * sigma)
    
                float invThresholdSqx2 = .5 / (threshold * threshold);     // 1.0 / (sigma^2 * 2.0)
                float invThresholdSqrt2PI = INV_SQRT_OF_2PI / threshold;   // 1.0 / (sqrt(2*PI) * sigma)
    
                float4 centrPx = tex2D(_MainTex, uv);
    
                float zBuff = 0.0;
                float4 aBuff = 0;
                float2 size = _MainTex_TexelSize.zw;
    
                for(float x=-radius; x <= radius; x++) {
                    float pt = sqrt(radQ-x*x);  // pt = yRadius: have circular trend
                    for(float y=-pt; y <= pt; y++) {
                        float2 d = float2(x,y);

                        float blurFactor = exp( -dot(d , d) * invSigmaQx2 ) * invSigmaQx2PI; 
            
                        float4 walkPx = tex2D(_MainTex,uv+d/size);

                        float4 dC = walkPx-centrPx;
                        float deltaFactor = exp( -dot(dC, dC) * invThresholdSqx2) * invThresholdSqrt2PI * blurFactor;
                                 
                        zBuff += deltaFactor;
                        aBuff += deltaFactor*walkPx;
                    }
                }
                return aBuff/zBuff;
            }

            //  About Standard Deviations (watch Gauss curve)
            //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            //
            //  kSigma = 1*sigma cover 68% of data
            //  kSigma = 2*sigma cover 95% of data - but there are over 3 times 
            //                   more points to compute
            //  kSigma = 3*sigma cover 99.7% of data - but needs more than double 
            //                   the calculations of 2*sigma


            //  Optimizations (description)
            //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            //
            //  fX = exp( -(x*x) * invSigmaSqx2 ) * invSigmaxSqrt2PI; 
            //  fY = exp( -(y*y) * invSigmaSqx2 ) * invSigmaxSqrt2PI; 
            //  where...
            //      invSigmaSqx2     = 1.0 / (sigma^2 * 2.0)
            //      invSigmaxSqrt2PI = 1.0 / (sqrt(2 * PI) * sigma)
            //
            //  now, fX*fY can be written in unique expression...
            //
            //      e^(a*X) * e^(a*Y) * c*c
            //
            //      where:
            //        a = invSigmaSqx2, X = (x*x), Y = (y*y), c = invSigmaxSqrt2PI
            //
            //           -[(x*x) * 1/(2 * sigma^2)]             -[(y*y) * 1/(2 * sigma^2)] 
            //          e                                      e
            //  fX = -------------------------------    fY = -------------------------------
            //                ________                               ________
            //              \/ 2 * PI  * sigma                     \/ 2 * PI  * sigma
            //
            //      now with... 
            //        a = 1/(2 * sigma^2), 
            //        X = (x*x) 
            //        Y = (y*y) ________
            //        c = 1 / \/ 2 * PI  * sigma
            //
            //      we have...
            //              -[aX]              -[aY]
            //        fX = e      * c;   fY = e      * c;
            //
            //      and...
            //                 -[aX + aY]    [2]     -[a(X + Y)]    [2]
            //        fX*fY = e           * c     = e            * c   
            //
            //      well...
            //
            //                    -[(x*x + y*y) * 1/(2 * sigma^2)]
            //                   e                                
            //        fX*fY = --------------------------------------
            //                                        [2]           
            //                          2 * PI * sigma           
            //      
            //      now with assigned constants...
            //
            //          invSigmaQx2   = 1/(2 * sigma^2)
            //          invSigmaQx2PI = 1/(2 * PI * sigma^2) = invSigmaQx2 * INV_PI 
            //
            //      and the kernel vector 
            //
            //          k = float2(x,y)
            //
            //      we can write:
            //
            //          fXY = exp( -dot(k,k) * invSigmaQx2) * invSigmaQx2PI
            //

            float4 frag(v2f i) : SV_Target
            {
                float3 denoisedColor;
                denoisedColor = sirBirdDenoise(i.uv);
                //denoisedColor = smartDeNoise(i.uv, 5.0, 2.0, .100);
                return float4(denoisedColor, 1);
            }
            ENDCG
        }
    }
}
