Shader "MyCustom/AddShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        // 抗锯齿做平均化是一个blend的操作
        Blend SrcAlpha OneMinusSrcAlpha
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
            sampler2D _AO;
            float4 _MainTex_ST;
            float _SamplePrePixel;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed ao = tex2D(_AO, i.uv);
                // 做一个低通滤波，起到抗锯齿的作用
                // 相当于加一层后期处理，即平均化
                col.rgb *= ao;
                col.a = 1.0f / (_SamplePrePixel + 1.0f);
                return col;
            }
            ENDCG
        }
    }
}
