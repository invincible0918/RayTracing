Shader "MyCustom/DownSample"
{
    Properties
    {
        _MainTex        ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            int _DownSampleBlurSize;
            float _DownSampleBlurSigma;

            float GaussWeight2D(float x, float y, float sigma)
            {
                float PI = 3.14159265358;
                float E  = 2.71828182846;
                float sigma_2 = pow(sigma, 2);

                float a = -(x*x + y*y) / (2.0 * sigma_2);
                return pow(E, a) / (2.0 * PI * sigma_2);
            }

            float3 GaussNxN(sampler2D tex, float2 uv, int n, float2 stride, float sigma)
            {
                float3 color = float3(0, 0, 0);
                int r = n / 2;
                float weight = 0.0;

                for(int i=-r; i<=r; i++)
                {
                    for(int j=-r; j<=r; j++)
                    {
                        float w = GaussWeight2D(i, j, sigma);
                        float2 coord = uv + float2(i, j) * stride;
                        color += tex2D(tex, coord).rgb * w;
                        weight += w;
                    }
                }

                color /= weight;
                return color;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = 0;
                float2 stride = _MainTex_ST.xy;

                col.rgb = GaussNxN(_MainTex, i.uv, _DownSampleBlurSize, stride, _DownSampleBlurSigma);
                return col;
            }
            ENDCG
        }
    }
}
