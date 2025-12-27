Shader "Custom/StylizedWater"
{
    Properties
    {
        [Header(Colors)]
        _ShallowColor ("Shallow Color", Color) = (0.2, 0.6, 0.8, 0.8)
        _DeepColor ("Deep Color", Color) = (0.0, 0.2, 0.4, 0.9)
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 0.8)
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        
        [Header(Wave Settings)]
        _WaveSpeed ("Wave Speed", Range(0, 2)) = 0.5
        _WaveScale ("Wave Scale", Range(0.1, 10)) = 2
        _WaveHeight ("Wave Height", Range(0, 0.5)) = 0.1
        _WaveDirection ("Wave Direction", Vector) = (1, 0, 0.5, 0)
        
        [Header(Surface)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.9
        _FresnelPower ("Fresnel Power", Range(1, 10)) = 3
        _Transparency ("Transparency", Range(0, 1)) = 0.7
        
        [Header(Foam)]
        _FoamAmount ("Foam Amount", Range(0, 1)) = 0.3
        _FoamScale ("Foam Scale", Range(1, 20)) = 8
        
        [Header(Grid Overlay)]
        _GridColor ("Grid Color", Color) = (1, 1, 1, 0.15)
        _GridScale ("Grid Scale", Range(0.5, 10)) = 2
        _GridThickness ("Grid Thickness", Range(0.01, 0.2)) = 0.05
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float fogFactor : TEXCOORD4;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _ShallowColor;
                float4 _DeepColor;
                float4 _FoamColor;
                float4 _SpecularColor;
                float _WaveSpeed;
                float _WaveScale;
                float _WaveHeight;
                float4 _WaveDirection;
                float _Smoothness;
                float _FresnelPower;
                float _Transparency;
                float _FoamAmount;
                float _FoamScale;
                float4 _GridColor;
                float _GridScale;
                float _GridThickness;
            CBUFFER_END
            
            // Simple noise function
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }
            
            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                
                float a = hash(i);
                float b = hash(i + float2(1, 0));
                float c = hash(i + float2(0, 1));
                float d = hash(i + float2(1, 1));
                
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }
            
            float fbm(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                for (int i = 0; i < 4; i++)
                {
                    value += amplitude * noise(p);
                    p *= 2.0;
                    amplitude *= 0.5;
                }
                return value;
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                float3 posOS = input.positionOS.xyz;
                
                // Animate waves
                float2 waveUV = posOS.xz * _WaveScale + _Time.y * _WaveSpeed * _WaveDirection.xz;
                float waveOffset = sin(waveUV.x) * cos(waveUV.y * 0.7) * _WaveHeight;
                waveOffset += sin(waveUV.x * 0.5 + waveUV.y * 0.3 + _Time.y * _WaveSpeed * 0.7) * _WaveHeight * 0.5;
                
                posOS.y += waveOffset;
                
                output.positionWS = TransformObjectToWorld(posOS);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.uv = input.uv;
                
                // Calculate animated normal
                float3 normalOS = input.normalOS;
                float dx = cos(waveUV.x) * _WaveHeight * _WaveScale;
                float dz = -sin(waveUV.y * 0.7) * 0.7 * _WaveHeight * _WaveScale;
                normalOS = normalize(float3(-dx, 1, -dz));
                
                output.normalWS = TransformObjectToWorldNormal(normalOS);
                output.viewDirWS = GetWorldSpaceViewDir(output.positionWS);
                output.fogFactor = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = normalize(input.viewDirWS);
                
                // Get main light
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                
                // Fresnel effect - edges are more opaque
                float fresnel = pow(1.0 - saturate(dot(normalWS, viewDirWS)), _FresnelPower);
                
                // Animated noise for water surface variation
                float2 noiseUV1 = input.positionWS.xz * 0.1 + _Time.y * _WaveSpeed * 0.3;
                float2 noiseUV2 = input.positionWS.xz * 0.15 - _Time.y * _WaveSpeed * 0.2;
                float surfaceNoise = fbm(noiseUV1) * 0.5 + fbm(noiseUV2) * 0.5;
                
                // Color blending based on fresnel and noise
                float3 waterColor = lerp(_ShallowColor.rgb, _DeepColor.rgb, fresnel * 0.5 + surfaceNoise * 0.3);
                
                // Foam (appears on wave peaks)
                float foam = smoothstep(0.5 - _FoamAmount, 0.5 + _FoamAmount, 
                    fbm(input.positionWS.xz * _FoamScale + _Time.y * _WaveSpeed));
                waterColor = lerp(waterColor, _FoamColor.rgb, foam * _FoamColor.a * 0.3);
                
                // Grid overlay for better depth perception
                float2 gridUV = input.positionWS.xz * _GridScale;
                float2 gridLines = abs(frac(gridUV) - 0.5);
                float grid = 1.0 - smoothstep(_GridThickness, _GridThickness + 0.02, min(gridLines.x, gridLines.y));
                waterColor = lerp(waterColor, _GridColor.rgb, grid * _GridColor.a);
                
                // Lighting
                float NdotL = saturate(dot(normalWS, lightDir));
                float3 diffuse = waterColor * mainLight.color * (NdotL * 0.5 + 0.5); // Half-lambert
                
                // Specular (sun reflection)
                float3 halfDir = normalize(lightDir + viewDirWS);
                float NdotH = saturate(dot(normalWS, halfDir));
                float specular = pow(NdotH, _Smoothness * 128.0) * _Smoothness;
                float3 specularColor = _SpecularColor.rgb * mainLight.color * specular;
                
                // Final color
                float3 finalColor = diffuse + specularColor;
                
                // Alpha based on fresnel and transparency setting
                float alpha = lerp(_Transparency, 1.0, fresnel * 0.5);
                alpha = lerp(alpha, _ShallowColor.a, 0.3);
                
                // Apply fog
                finalColor = MixFog(finalColor, input.fogFactor);
                
                return float4(finalColor, alpha);
            }
            ENDHLSL
        }
        
        // Shadow caster pass (optional, for casting shadows)
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            Varyings ShadowVert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }
            
            float4 ShadowFrag(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}
