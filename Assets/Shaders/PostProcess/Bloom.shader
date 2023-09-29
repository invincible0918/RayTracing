Shader "MyCustom/Bloom"
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
            sampler2D _BloomTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float _BloomIntensity;

            float3 ACESToneMapping(float3 color, float adapted_lum)
            {
                const float A = 2.51f;
                const float B = 0.03f;
                const float C = 2.43f;
                const float D = 0.59f;
                const float E = 0.14f;

                color *= adapted_lum;
                return (color * (A * color + B)) / (color * (C * color + D) + E);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed3 bloom = tex2D(_BloomTex, i.uv).rgb * _BloomIntensity;
                bloom = ACESToneMapping(bloom, 1.0);

                // gamma
                float g = 1.0 / 2.2;
                bloom = saturate(pow(bloom, float3(g, g, g)));

                col.rgb += bloom.rgb;

                return col;
            }
            ENDCG
        }
    }
}
