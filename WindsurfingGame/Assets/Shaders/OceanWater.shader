// Ocean water for the Windsurfing Simulator (URP, Unity 6).
//
// Vertex stage : Gerstner wave displacement. The wave parameters arrive as shader globals
//                published by WaterSurface.cs, so the rendered surface is identical to the
//                physics surface the board floats on. AccumulateGerstner() MUST match
//                GerstnerMath.Displacement() in GerstnerWave.cs.
// Fragment     : depth-based colour and refraction (camera depth + opaque textures),
//                sky reflection with Fresnel, sun glints, procedural wind ripples,
//                foam at geometry intersections (hull, islands), wave crests and wind streaks.
//
// Requires "Depth Texture" and "Opaque Texture" on the URP asset (enabled on PC_RPAsset).
// Turn off "Use Scene Depth" on the material if the pipeline asset lacks them.
Shader "Windsurfing/OceanWater"
{
    Properties
    {
        [Header(Colour)]
        _ShallowColor ("Shallow Colour (light through water)", Color) = (0.25, 0.65, 0.70, 1)
        _DeepColor ("Deep Colour", Color) = (0.012, 0.11, 0.26, 1)
        _DepthFade ("Depth Colour Distance (m)", Range(0.1, 40)) = 5
        _ScatterColor ("Crest Scatter Colour", Color) = (0.10, 0.60, 0.55, 1)
        _ScatterStrength ("Crest Scatter Strength", Range(0, 2)) = 0.6

        [Header(Surface Detail)]
        _RippleScale ("Ripple Scale", Range(0.05, 5)) = 0.7
        _RippleStrength ("Ripple Strength", Range(0, 1)) = 0.3
        _RippleSpeed ("Ripple Speed", Range(0, 3)) = 0.9

        [Header(Lighting)]
        _Smoothness ("Smoothness", Range(0.5, 1)) = 0.94
        _ReflectionStrength ("Sky Reflection", Range(0, 2)) = 1
        _SpecularPower ("Sun Glint Tightness", Range(8, 2048)) = 400
        _SpecularStrength ("Sun Glint Strength", Range(0, 5)) = 2
        _RefractionStrength ("Refraction Distortion", Range(0, 0.2)) = 0.035
        [Toggle] _UseSceneDepth ("Use Scene Depth (needs Depth and Opaque Texture)", Float) = 1

        [Header(Foam)]
        _FoamColor ("Foam Colour", Color) = (0.93, 0.97, 1, 1)
        _EdgeFoamDistance ("Edge Foam Distance (m)", Range(0.05, 3)) = 0.5
        _CrestFoamThreshold ("Crest Foam Threshold", Range(0, 1)) = 0.55
        _CrestFoamStrength ("Crest Foam Strength", Range(0, 1)) = 0.5
        _WindStreakStrength ("Wind Streak Strength", Range(0, 1)) = 0.3
        _FoamScale ("Foam Noise Scale", Range(0.05, 4)) = 0.6

        [Header(Debug)]
        [Toggle] _GridEnabled ("Show 2 m Grid", Float) = 0
        _GridColor ("Grid Colour", Color) = (1, 1, 1, 0.15)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "OceanForward"
            Tags { "LightMode" = "UniversalForward" }

            // The water composites the refracted scene colour itself, so it renders opaque
            // in the transparent queue (after the depth/opaque textures are copied).
            Blend Off
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _ShallowColor;
                float4 _DeepColor;
                float _DepthFade;
                float4 _ScatterColor;
                float _ScatterStrength;
                float _RippleScale;
                float _RippleStrength;
                float _RippleSpeed;
                float _Smoothness;
                float _ReflectionStrength;
                float _SpecularPower;
                float _SpecularStrength;
                float _RefractionStrength;
                float _UseSceneDepth;
                float4 _FoamColor;
                float _EdgeFoamDistance;
                float _CrestFoamThreshold;
                float _CrestFoamStrength;
                float _WindStreakStrength;
                float _FoamScale;
                float _GridEnabled;
                float4 _GridColor;
            CBUFFER_END

            // Globals published by WaterSurface.cs every frame (kept outside the per-material cbuffer)
            float4 _WaveA;          // xy = unit travel direction (x, z), z = steepness, w = wavelength
            float4 _WaveB;
            float4 _WaveC;
            float4 _WaveD;
            float4 _WaveAmplitudes; // amplitude per wave in metres, 0 = wave disabled
            float _WaterTime;       // seconds, matches Time.time on the CPU
            float4 _WaterWind;      // xy = direction the wind blows TO, z = speed in m/s

            #define WATER_GRAVITY 9.81

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                // x = crest factor (-1 trough .. +1 crest), y = wave height (m),
                // z = view-space depth of the surface (m), w = total steepness
                float4 waveData : TEXCOORD2;
                float fogFactor : TEXCOORD3;
            };

            // ---------------------------------------------------------------------------
            // Gerstner waves - must match GerstnerMath.Displacement() in GerstnerWave.cs
            // ---------------------------------------------------------------------------
            void AccumulateGerstner(float4 wave, float amplitude, float2 restXZ, float t,
                                    inout float3 displacement, inout float3 normalAccum, inout float crest)
            {
                if (amplitude <= 0.0) return;

                float k = 2.0 * PI / max(wave.w, 0.5);
                float c = sqrt(WATER_GRAVITY / k);
                float2 d = normalize(wave.xy + float2(1e-5, 0.0));
                float phase = k * (dot(d, restXZ) - c * t);

                float s = sin(phase);
                float co = cos(phase);

                // Horizontal displacement scales with steepness / k, vertical with amplitude
                float horizontal = wave.z / k * co;
                displacement += float3(d.x * horizontal, amplitude * s, d.y * horizontal);

                // Analytic normal (GPU Gems ch. 1, eq. 12)
                float wa = k * amplitude;
                normalAccum.x -= d.x * wa * co;
                normalAccum.z -= d.y * wa * co;
                normalAccum.y -= wave.z * s;

                crest += wave.z * s;
            }

            // ---------------------------------------------------------------------------
            // Cheap procedural noise for ripples and foam
            // ---------------------------------------------------------------------------
            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float valueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = hash21(i);
                float b = hash21(i + float2(1.0, 0.0));
                float c = hash21(i + float2(0.0, 1.0));
                float d = hash21(i + float2(1.0, 1.0));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            // Three octaves, output roughly 0..0.9
            float fbm(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                for (int i = 0; i < 3; i++)
                {
                    value += amplitude * valueNoise(p);
                    p = p * 2.03 + 17.1;
                    amplitude *= 0.5;
                }
                return value;
            }

            // ---------------------------------------------------------------------------
            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);

                float3 displacement = float3(0.0, 0.0, 0.0);
                float3 normalAccum = float3(0.0, 1.0, 0.0);
                float crest = 0.0;

                AccumulateGerstner(_WaveA, _WaveAmplitudes.x, positionWS.xz, _WaterTime, displacement, normalAccum, crest);
                AccumulateGerstner(_WaveB, _WaveAmplitudes.y, positionWS.xz, _WaterTime, displacement, normalAccum, crest);
                AccumulateGerstner(_WaveC, _WaveAmplitudes.z, positionWS.xz, _WaterTime, displacement, normalAccum, crest);
                AccumulateGerstner(_WaveD, _WaveAmplitudes.w, positionWS.xz, _WaterTime, displacement, normalAccum, crest);

                float totalSteepness = (_WaveAmplitudes.x > 0.0 ? _WaveA.z : 0.0)
                                     + (_WaveAmplitudes.y > 0.0 ? _WaveB.z : 0.0)
                                     + (_WaveAmplitudes.z > 0.0 ? _WaveC.z : 0.0)
                                     + (_WaveAmplitudes.w > 0.0 ? _WaveD.z : 0.0);

                positionWS += displacement;

                output.positionWS = positionWS;
                output.normalWS = normalize(normalAccum);
                output.positionCS = TransformWorldToHClip(positionWS);

                float viewDepth = -TransformWorldToView(positionWS).z;
                output.waveData = float4(crest / max(totalSteepness, 0.001), displacement.y, viewDepth, totalSteepness);
                output.fogFactor = ComputeFogFactor(output.positionCS.z);

                return output;
            }

            // ---------------------------------------------------------------------------
            float4 frag(Varyings input, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC) : SV_Target
            {
                bool isFrontFace = IS_FRONT_VFACE(cullFace, true, false);

                float3 positionWS = input.positionWS;
                float3 viewDirWS = normalize(GetWorldSpaceViewDir(positionWS));
                float3 waveNormal = normalize(input.normalWS);
                float surfaceDepth = input.waveData.z;

                // ----- Wind ripples: procedural detail normal scrolling with the wind -----
                float2 windDir = normalize(_WaterWind.xy + float2(1e-4, 0.0));
                float windSpeed = _WaterWind.z;

                float2 flow = windDir * (_RippleSpeed * (0.3 + windSpeed * 0.08)) * _WaterTime;
                float2 p1 = positionWS.xz * _RippleScale + flow;
                float2 p2 = positionWS.xz * _RippleScale * 2.7 - flow * 0.6 + 13.7;

                const float e = 0.15;
                float h0 = fbm(p1) + 0.6 * fbm(p2);
                float hx = fbm(p1 + float2(e, 0.0)) + 0.6 * fbm(p2 + float2(e * 2.7, 0.0));
                float hz = fbm(p1 + float2(0.0, e)) + 0.6 * fbm(p2 + float2(0.0, e * 2.7));
                float2 gradient = float2(hx - h0, hz - h0) / e;

                // More ripples in more wind, fewer far away (avoids shimmering at the horizon)
                float rippleStrength = _RippleStrength * (0.4 + saturate(windSpeed / 10.0) * 0.6);
                rippleStrength /= (1.0 + surfaceDepth * 0.01);

                float3 detailNormal = normalize(float3(-gradient.x * rippleStrength, 1.0, -gradient.y * rippleStrength));
                float3 normalWS = normalize(float3(waveNormal.x + detailNormal.x,
                                                   waveNormal.y * detailNormal.y,
                                                   waveNormal.z + detailNormal.z));

                float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);

                // ----- Scene depth: water thickness in front of whatever is behind this pixel -----
                float waterDepth = 1000.0;
                float3 sceneColor = _DeepColor.rgb;

                if (_UseSceneDepth > 0.5)
                {
                    float sceneEyeDepth = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
                    waterDepth = max(sceneEyeDepth - surfaceDepth, 0.0);

                    // Refraction: distort the opaque colour by the normal, but never show
                    // objects that are in front of the water surface
                    float2 refractedUV = screenUV + normalWS.xz * _RefractionStrength * saturate(waterDepth * 0.5);
                    float refractedEyeDepth = LinearEyeDepth(SampleSceneDepth(refractedUV), _ZBufferParams);
                    if (refractedEyeDepth < surfaceDepth)
                    {
                        refractedUV = screenUV;
                    }
                    sceneColor = SampleSceneColor(refractedUV);
                }

                // ----- Lighting inputs -----
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 lightDir = normalize(mainLight.direction);
                float shadow = mainLight.shadowAttenuation;
                float3 lightColor = mainLight.color * shadow;
                float3 ambient = SampleSH(normalWS);
                float ndotl = saturate(dot(normalWS, lightDir));

                // ----- Water body colour: light coming up through the water, absorbed with depth -----
                float depthFactor = 1.0 - exp(-waterDepth / max(_DepthFade, 0.01));
                float3 absorbed = sceneColor * _ShallowColor.rgb;
                float3 waterBody = lerp(absorbed, _DeepColor.rgb, depthFactor);
                float3 body = waterBody * (ambient * 0.8 + lightColor * (0.35 + 0.65 * ndotl));

                // Back-lit crests glow (cheap subsurface scattering)
                float crestFactor = input.waveData.x;
                float backlight = pow(saturate(dot(viewDirWS, -lightDir)), 3.0);
                float scatter = _ScatterStrength * backlight * (0.25 + 0.75 * saturate(crestFactor)) * saturate(input.waveData.w * 3.0 + 0.2);
                body += _ScatterColor.rgb * scatter * lightColor;

                // ----- Reflection with Fresnel -----
                float fresnel = 0.02 + 0.98 * pow(1.0 - saturate(dot(normalWS, viewDirWS)), 5.0);
                float3 reflectDir = reflect(-viewDirWS, normalWS);
                reflectDir.y = abs(reflectDir.y); // never reflect the ground half of the skybox
                float3 skyReflection = GlossyEnvironmentReflection(reflectDir, positionWS, 1.0 - _Smoothness, 1.0, screenUV) * _ReflectionStrength;

                // ----- Sun glints -----
                float3 halfDir = normalize(lightDir + viewDirWS);
                float ndoth = saturate(dot(normalWS, halfDir));
                float glint = pow(ndoth, _SpecularPower) * _SpecularStrength;
                float glitter = pow(ndoth, _SpecularPower * 0.15) * _SpecularStrength * 0.08;
                float3 specular = (glint + glitter) * lightColor;

                // ----- Foam -----
                float foamNoise = fbm(positionWS.xz * _FoamScale + windDir * _WaterTime * 0.4);
                float foamNoise2 = fbm(positionWS.xz * _FoamScale * 3.1 - windDir * _WaterTime * 0.7 + 5.3);

                // Foam where the water meets geometry (hull, islands)
                float edge = 1.0 - saturate(waterDepth / _EdgeFoamDistance);
                float edgeFoam = smoothstep(0.0, 1.0, edge) * saturate(foamNoise2 * 1.6 + edge - 0.5);

                // Foam on wave crests (only when waves are enabled)
                float crestFoam = smoothstep(_CrestFoamThreshold, 1.0, crestFactor * (0.6 + 0.4 * foamNoise))
                                * _CrestFoamStrength * saturate(input.waveData.w * 3.0);

                // Wind streaks: noise stretched along the wind direction
                float2 windPerp = float2(-windDir.y, windDir.x);
                float2 streakUV = float2(dot(positionWS.xz, windDir) * 0.04 - _WaterTime * windSpeed * 0.06,
                                         dot(positionWS.xz, windPerp) * 0.5);
                float streak = pow(saturate(fbm(streakUV) * 1.4 - 0.35), 2.5) * _WindStreakStrength * saturate((windSpeed - 4.0) / 8.0);

                float foam = saturate(edgeFoam + crestFoam + streak);
                float3 foamColor = _FoamColor.rgb * (ambient + lightColor * (0.5 + 0.5 * ndotl));

                // ----- Combine -----
                float3 color = lerp(body, skyReflection, fresnel) + specular;
                color = lerp(color, foamColor, foam);

                if (_GridEnabled > 0.5)
                {
                    float2 gridCell = abs(frac(positionWS.xz * 0.5) - 0.5);
                    float gridLine = 1.0 - smoothstep(0.0, 0.03, min(gridCell.x, gridCell.y));
                    color = lerp(color, _GridColor.rgb, gridLine * _GridColor.a);
                }

                if (!isFrontFace)
                {
                    // Camera is under the surface: murky underside
                    color = lerp(color, _DeepColor.rgb * 0.5, 0.85);
                }

                color = MixFog(color, input.fogFactor);
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Unlit"
}
