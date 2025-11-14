public module depth;

// These expect NDC[-1:+1] depth in/out

float linearizeDepth(const in float ndcDepth, const in float zNear, const in float zFar) {
    return 2.0 * zNear * zFar / (zFar + zNear - ndcDepth * (zFar - zNear));
}

float delinearizeDepth(const in float linearDepth, const in float zNear, const in float zFar) {
    return (zFar + zNear - 2.0 * zNear * zFar / linearDepth) / (zFar - zNear);
}
