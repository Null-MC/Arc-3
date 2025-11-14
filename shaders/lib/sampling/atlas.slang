public module atlas;

struct AtlasBounds {
    float2 CoordMin = 0;
    float2 CoordSize = 0;

    float2 GetAtlasCoord(const in float2 localCoord) {
        return fract(localCoord) * CoordSize + CoordMin;
    }

    float2 GetLocalCoord(const in float2 atlasCoord) {
        return (atlasCoord - CoordMin) / CoordSize;
    }

    [mutating]
    void Populate(const in float2 texcoord, const in float2 midTexCoord) {
        float2 coordNMid = texcoord - midTexCoord;

        CoordMin = min(texcoord, midTexCoord - coordNMid);
        CoordSize = abs(coordNMid) * 2.0;
    }
};
