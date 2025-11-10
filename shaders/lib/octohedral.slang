import lib.common;


half2 OctWrap(const in half2 v) {
    return (1.0 - abs(v.yx)) * select(v.xy >= 0.0, 1.0, -1.0);
}

half2 OctEncode(half3 n) {
    n /= sumOf(abs(n));
    n.xy = n.z >= 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

half3 OctDecode(half2 f) {
    f = f * 2.0 - 1.0;
 
    // https://twitter.com/Stubbesaurus/status/937994790553227264
    half3 n = half3(f.xy, 1.0 - sumOf(abs(f.xy)));
    float t = saturate(-n.z);
    n.xy += select(n.xy >= 0.0, -t, t);
    return normalize(n);
}
