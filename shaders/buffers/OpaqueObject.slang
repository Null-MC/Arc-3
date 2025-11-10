import lib.octohedral;


struct OpaqueObject_Normals {
    half3 geo;
    half3 tex;

    uint2 pack() {
        half2 packed_geo = OctEncode(geo);
        half2 packed_tex = OctEncode(tex);

        return uint2(
            packUnorm4x8(half4(packed_geo, packed_tex)),
            0);
    }

    [mutating]
    void unpack(const in uint2 data) {
        half4 packedNormalData = unpackUnorm4x8ToHalf(data.r);
        geo = OctDecode(packedNormalData.xy);
        tex = OctDecode(packedNormalData.zw);
    }
};

struct OpaqueObject_MatLit {
    half4 specular;
    float occlusion;
    half2 lmcoord;

    uint2 pack() {
        return uint2(
            packUnorm4x8(specular),
            packUnorm4x8(half4(lmcoord, occlusion, 0.0)));
    }

    [mutating]
    void unpack(const in uint2 data) {
        specular = unpackUnorm4x8ToHalf(data.r);

        half4 mat_lit = unpackUnorm4x8ToHalf(data.g);
        lmcoord = mat_lit.rg;
        occlusion = mat_lit.b;
    }
};
