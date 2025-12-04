public module HCM;

import lib.light.fresnel;

// https://helpx.adobe.com/substance-3d-general/adobe-standard-material/metal-material-references.html

static const LazanyiF lazanyi_hcm[8] = LazanyiF[](
    LazanyiF( // iron
        half3(0.953, 0.945, 0.914),
        half3(0.933, 0.945, 0.953)),

    LazanyiF( // gold
        half3(1.000, 0.859, 0.596),
        half3(0.973, 0.984, 0.961)),

    LazanyiF( // aluminum
        half3(0.961, 0.965, 0.965),
        half3(0.961, 0.973, 0.980)),

    LazanyiF( // chrome
        half3(0.769, 0.773, 0.769),
        half3(0.875, 0.882, 0.914)),

    LazanyiF( // copper
        half3(1.000, 0.827, 0.753),
        half3(0.988, 0.972, 0.969)),

    LazanyiF( // lead
        half3(0.79, 0.87, 0.85),
        half3(0.83, 0.80, 0.83)),

    LazanyiF( // platinum
        half3(0.980, 0.969, 0.918),
        half3(0.976, 0.976, 0.973)),

    LazanyiF( // silver
        half3(0.996, 0.992, 0.984),
        half3(0.996, 1.000, 1.000))
);
