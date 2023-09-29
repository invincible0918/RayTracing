Shader "MyCustom/ColorGrading"
{
    Properties
    {
        _MainTex        ("Texture", 2D) = "white" {}
        _LutTex			("_LutTex", 2D)="white"{}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

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
            sampler2D _LutTex;
			float4 _LutTex_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            static const float blockSize = 32.0;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                col.rgb = LinearToGammaSpace(col.rgb);

                float leftBlockIndex = floor(col.b * blockSize);
                float rightBlockIndex = min(leftBlockIndex + 1, blockSize - 1);

                float threshold = (blockSize - 1.0) / blockSize;

                float2 uvLeft = float2(leftBlockIndex / blockSize + col.r * threshold / blockSize, col.g * threshold);
                float2 uvRight = float2(rightBlockIndex / blockSize + col.r * threshold / blockSize, col.g * threshold);

                fixed4 col0 = tex2D(_LutTex, uvLeft);
				fixed4 col1 = tex2D(_LutTex, uvRight);

                // 最后，根据b值进行插值
                col.rgb = lerp(col0.rgb, col1.rgb, frac(col.b * blockSize));
                col.rgb = GammaToLinearSpace(col.rgb);
                return col;
            }
            ENDCG
        }
    }
}
