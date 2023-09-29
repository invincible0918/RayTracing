Shader "MyCustom/ColorCorrection"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            half _Brightness;
            half _Saturation;
            half _Contrast;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                // Brightness
                fixed3 color = col.rgb * _Brightness;

                // Saturation
                fixed3 gray = fixed3(0.2125, 0.7154, 0.0721);
                // 构成最低灰度的图像
                fixed minGray = dot(gray, col.rgb);
                fixed3 grayColor = fixed3(minGray, minGray, minGray);
                color = lerp(grayColor, color, _Saturation);

                // Contrast
                // 构成最低对比度的图像
                fixed3 minContrast = fixed3(0.5, 0.5, 0.5);
                color = lerp(minContrast, color, _Contrast);

                // 得到最终图像之后，再将alpha合并回来
                fixed4 finalColor = fixed4(color, col.a);

                return finalColor;
            }
            ENDCG
        }
    }
}
