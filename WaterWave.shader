// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/WaterWave"
{
    Properties
    {
        _Color ("Basic Color Bias", Color) = (0.0, 0.5, 0.3, 1)
        _Gloss ("Gloss", Range(0.5, 50)) = 16
        _SpecularScale("Specular Scale", Float) = 20.0
        _MainTex ("Base RGB", 2D) = "white" {}
        _WaveMap ("Wave Normal Map", 2D) = "bump" {}
        //_CubeMap("Cube Map", Cube) = "_Skybox" {}
        _WaveXSpeed("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01
        _WaveYSpeed("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
        _Distortion("Distortion", Range(0, 100)) = 10
        _Refraction_Amount("Refraction Amount", Range(0.0, 1.0)) = 0.5
        _Magnitude ("Wave Magnitude", Float) = 1.0
        _Frequency ("Wave Frequency", Float) = 1.0
        _InvWaveLength ("Distortion Inverse Wave Length", Float) = 10
    }
    SubShader
    {
        //Tags {"Queue" = "Transparent" "RenderType" = "Opaque"}
        //Tags {"Queue" = "Transparent" "RenderType" = "Opaque" "IgnoreProjector" = "True" "DisableBatching" = "True"}
        Tags {"Queue" = "Transparent" "RenderType" = "Opaque"}
        GrabPass { "_RefractionTex" }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            Zwrite Off
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _WaveMap;
            float4 _WaveMap_ST;
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize;
            //samplerCUBE _CubeMap;
            float _WaveXSpeed;
            float _WaveYSpeed;
            float _Distortion;
            float _Refraction_Amount;
            float _Gloss;
            float _SpecularScale;
            float _Magnitude;
            float _Frequency;
            float _InvWaveLength;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 scrPos : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 uv : TEXCOORD2;
                float3 TtoW0 : TEXCOORD3;
                float3 TtoW1 : TEXCOORD4;
                float3 TtoW2 : TEXCOORD5;
                float disBias: TEXCOORD6;
            };

            v2f vert (appdata v)
            {
                v2f o;

                float4 offsetWave = 0;
                //offsetWave.y = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
                float waveBase = _Frequency * _Time.y - v.vertex.z * _InvWaveLength;
                float sinValue = sin(waveBase);
                float cosValue = cos(waveBase - 1.0);
                float temp = frac(abs(waveBase - 1.57) / 3.14);
                o.disBias = 1 / (abs(temp * 3.14) + 0.05);
                //half temp1 = waveBase / 1.57;
                //half temp2 = temp1 - min(abs(temp1 - floor(temp1)), abs(temp1 - ceil(temp1)));
                //o.disBias = min(1/abs(temp2 * 1.57 - v.vertex.z),100);

                offsetWave.y = sinValue * _Magnitude;
                o.pos = UnityObjectToClipPos(v.vertex + offsetWave);

                half3 normalOffset = normalize(half3(0,1/((-cosValue) * _Magnitude) , 1));

                v.normal = normalize(float3(0, normalOffset.y * v.normal.y, v.normal.z));
                //o.pos = UnityObjectToClipPos(v.vertex);

                o.scrPos = ComputeGrabScreenPos(o.pos);

                o.worldPos = mul(unity_ObjectToWorld, o.pos);

                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);

                float3 worldTangent = UnityObjectToWorldDir(v.tangent);
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldBinormal = normalize(cross(worldTangent, worldNormal) * v.tangent.w);

                o.TtoW0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
                o.TtoW1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
                o.TtoW2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 halfDir = (viewDir + lightDir) / 2;

                float2 drift = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);

                fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + drift)).rgb;
                fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - drift)).rgb;
                fixed3 bump = normalize(bump1 + bump2);

                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy; //实在没搞懂啥意思
                fixed3 zhesColor = tex2D(_RefractionTex, i.scrPos.xy / i.scrPos.w).rgb;

                bump = normalize(half3(dot(i.TtoW0, bump), dot(i.TtoW1, bump), dot(i.TtoW2, bump)));

                //fixed4 texColor = tex2D(_MainTex, i.uv.xy + drift);
                fixed4 texColor = tex2D(_MainTex, i.uv.xy);

                //fixed3 reflDir = reflect(-lightDir, bump);
                fixed3 reflCol = texColor.rgb * _Color;

                //fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * reflCol;

                //fixed3 specular = _LightColor0.rgb * pow(saturate(dot(bump, halfDir)), _Gloss) * _SpecularScale;
                fixed3 specular = _LightColor0.rgb * pow(abs(dot(bump, halfDir)), _Gloss) * _SpecularScale * i.disBias;

                //fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 5);

                //fixed3 finalColor = (reflCol + specular) * fresnel + zhesColor * (1 - fresnel);
                fixed3 finalColor = (reflCol + specular) * (1-_Refraction_Amount) + zhesColor * _Refraction_Amount;

                return fixed4 (finalColor, 1.0);
            }
            ENDCG
        }
    }
}
