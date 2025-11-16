public module object_data;

import lib.octohedral;


struct ObjectData_Normals {
    half3 geo;
    half3 tex;

    uint2 pack() {
        return uint2(
            packUnorm2x16(OctEncode(geo)),
            packUnorm2x16(OctEncode(tex)));
    }

    [mutating]
    void unpack(const in uint2 data) {
        geo = unpackGeo(data.r);
        tex = unpackTex(data.g);
    }

    static half3 unpackGeo(const in uint data_r) {
        return OctDecode(unpackUnorm2x16ToHalf(data_r));
    }

    static half3 unpackTex(const in uint data_g) {
        return OctDecode(unpackUnorm2x16ToHalf(data_g));
    }
};

struct ObjectData_MatLit {
    half4 specular;
    half occlusion;
    half2 lmcoord;
    uint blockMapId;

    uint2 pack() {
        uint2 data = uint2(
            packUnorm4x8(specular),
            packUnorm4x8(half4(lmcoord, occlusion, (half)0.0)));

        data.g = bitfieldInsert(data.g, blockMapId, 24, 8);

        return data;
    }

    [mutating]
    void unpack(const in uint2 data) {
        unpackSpecular(data.r);
        unpackLightOcclusion(data.g);
    }

    [mutating]
    void unpackLightOcclusion(const in uint data_g) {
        half3 data = unpackUnorm4x8ToHalf(data_g).xyz;
        blockMapId = bitfieldExtract(data_g, 24, 8);
        lmcoord = data.xy;
        occlusion = data.z;
    }

    [mutating]
    void unpackSpecular(const in uint data_r) {
        specular = unpackUnorm4x8ToHalf(data_r);
    }

    // static void unpackSpecular(const in uint data_r, out half4 specularData) {
    //     specularData = unpackUnorm4x8ToHalf(data_r);
    // }

    // static void unpackLightOcclusion(const in uint data_g, out half2 lmcoord, out half occlusion, out int blockMapId) {
    //     half3 data = unpackUnorm4x8ToHalf(data_g).xyz;
    //     blockMapId = bitfieldExtract(data_g, 24, 8);
    //     lmcoord = data.xy;
    //     occlusion = data.z;
    // }
};
