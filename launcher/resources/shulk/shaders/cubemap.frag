#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float yaw;
    float pitch;
    float aspect;
    float fov;
};

layout(binding = 1) uniform sampler2D cubeAtlas;

void main() {
    vec2 ndc = (qt_TexCoord0 * 2.0 - 1.0);
    float tanHalfFov = tan(radians(fov * 0.5));
    vec3 ray = normalize(vec3(ndc.x * aspect * tanHalfFov, -ndc.y * tanHalfFov, 1.0));

    float cp = cos(pitch);
    float sp = sin(pitch);
    vec3 r1 = vec3(ray.x, ray.y * cp - ray.z * sp, ray.y * sp + ray.z * cp);

    float cy = cos(yaw);
    float sy = sin(yaw);
    vec3 v = vec3(r1.x * cy + r1.z * sy, r1.y, -r1.x * sy + r1.z * cy);

    vec3 absV = abs(v);
    vec2 uv;
    float faceIndex = 0.0;

    if (absV.x >= absV.y && absV.x >= absV.z) {
        if (v.x > 0.0) {
            uv = vec2(-v.z / absV.x, -v.y / absV.x);
            faceIndex = 1.0;
        } else {
            uv = vec2(v.z / absV.x, -v.y / absV.x);
            faceIndex = 3.0;
        }
    } else if (absV.y >= absV.x && absV.y >= absV.z) {
        if (v.y > 0.0) {
            uv = vec2(v.x / absV.y, v.z / absV.y);
            faceIndex = 4.0;
        } else {
            uv = vec2(v.x / absV.y, -v.z / absV.y);
            faceIndex = 5.0;
        }
    } else {
        if (v.z > 0.0) {
            uv = vec2(v.x / absV.z, -v.y / absV.z);
            faceIndex = 0.0;
        } else {
            uv = vec2(-v.x / absV.z, -v.y / absV.z);
            faceIndex = 2.0;
        }
    }

    uv = uv * 0.5 + 0.5;
    uv = clamp(uv, 0.002, 0.998);

    vec2 atlasUV = vec2((faceIndex + uv.x) / 6.0, uv.y);
    fragColor = texture(cubeAtlas, atlasUV) * qt_Opacity;
}
