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

    uint2 pack() {
        return uint2(
            packUnorm4x8(specular),
            packUnorm4x8(half4(lmcoord, occlusion, (half)0.0)));
    }

    [mutating]
    void unpack(const in uint2 data) {
        specular = unpackSpecular(data.r);

        half4 mat_lit = unpackLightOcclusion(data.g);
        lmcoord = mat_lit.rg;
        occlusion = mat_lit.b;
    }

    static half4 unpackSpecular(const in uint data_r) {
        return unpackUnorm4x8ToHalf(data_r);
    }

    static half4 unpackLightOcclusion(const in uint data_g) {
        return unpackUnorm4x8ToHalf(data_g);
    }
};
