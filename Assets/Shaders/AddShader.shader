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
		Blend SrcAlpha OneMinusSrcAlpha

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

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
			float _SamplePrePixel;

			float4 frag(v2f i) : SV_Target
			{
				// 做一个低通滤波就能起到一个抗锯齿的作用，相当于加一层后处理。工作原理就是平均化。
				return float4(tex2D(_MainTex, i.uv).rgb, 1.0f / (_SamplePrePixel + 1.0f));
			}
			ENDCG
		}
	}
}
