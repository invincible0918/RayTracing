// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "MyTest/NormalTest"
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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float3 worldNormal : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul((float3x3)unity_ObjectToWorld, v.normal);   // 1
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);   // 2
                //o.worldNormal = mul(v.normal, (float3x3)unity_ObjectToWorld);   // 3
                //o.worldNormal = v.normal;   // 4

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = fixed4(i.worldNormal, 1);  
                return col;
            }
            ENDCG
        }
    }
}
