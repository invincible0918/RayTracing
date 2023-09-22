Shader "MyCustom/SampleHemisphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"

    StructuredBuffer<float3> cb;

    struct v2f
    {
        float4 vertex : SV_POSITION;
    };
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            v2f vert (uint instanceID: SV_InstanceID)
            {
                v2f o;

                float4 vertex = float4(cb[instanceID], 1);
                o.vertex = UnityWorldToClipPos(vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(1, 0, 0, 1);
            }
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            v2f vert (uint instanceID: SV_InstanceID)
            {
                v2f o;

                float4 vertex = float4(cb[instanceID], 1);
                vertex.y = 0;
                o.vertex = UnityWorldToClipPos(vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return 1;
            }
            ENDCG
        }
    }
}
