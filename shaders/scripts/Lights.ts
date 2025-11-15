export function ApplyLightColors(coloredCandles: boolean) {
    setLightColorEx('#8053d1', 'amethyst_cluster');
    setLightColorEx('#5fc9cf', 'beacon');
    setLightColorEx('#f39e49', 'blast_furnace');
    setLightColorEx('#3e2d1f', 'brown_mushroom');
    setLightColorEx('#f39849', 'campfire');
    setLightColorEx('#935b2c', 'cave_vines', "cave_vines_plant");
    setLightColorEx('#29d4cf', 'conduit');
    setLightColorEx('#d39f6d', 'copper_bulb', 'waxed_copper_bulb');
    setLightColorEx('#d39255', 'exposed_copper_bulb', 'waxed_exposed_copper_bulb');
    setLightColorEx('#cf833a', 'weathered_copper_bulb', 'waxed_weathered_copper_bulb');
    setLightColorEx('#87480b', 'oxidized_copper_bulb', 'waxed_oxidized_copper_bulb');
    setLightColorEx('#d39f6d', 'copper_lantern', 'waxed_copper_lantern');
    setLightColorEx('#d39255', 'exposed_copper_lantern', 'waxed_exposed_copper_lantern');
    setLightColorEx('#cf833a', 'weathered_copper_lantern', 'waxed_weathered_copper_lantern');
    setLightColorEx('#87480b', 'oxidized_copper_lantern', 'waxed_oxidized_copper_lantern');
    setLightColorEx('#7f17a8', 'crying_obsidian', 'respawn_anchor');
    setLightColorEx('#371559', 'enchanting_table');
    setLightColorEx('#3d4d59', 'ender_chest');
    setLightColorEx('#ac9833', 'end_gateway');
    setLightColorEx('#5f33ac', 'end_portal');
    setLightColorEx('#ffffff', 'end_rod'); // Before: #f5e8d8 // I think there should be at least one completely white light source
    setLightColorEx('#bea935', 'firefly_bush');
    setLightColorEx('#f39e49', 'furnace');
    setLightColorEx('#5f9889', 'glow_lichen');
    setLightColorEx('#d3b178', 'glowstone');
    setLightColorEx('#c2985a', 'jack_o_lantern');
    setLightColorEx('#f39e49', 'lantern');
    setLightColorEx('#b8491c', 'lava', 'magma_block', 'lava_cauldron');
    setLightColorEx('#ffffff', 'light'); // Could be any color, but white makes sense
    setLightColorEx('#650a5e', 'nether_portal');
    setLightColorEx('#dfac47', 'ochre_froglight');
    setLightColorEx('#e075e8', 'pearlescent_froglight');
    setLightColorEx('#63e53c', 'verdant_froglight');
    setLightColorEx('#e0ba42', 'redstone_lamp');
    setLightColorEx('#f9321c', 'redstone_ore', 'deepslate_redstone_ore');
    setLightColorEx('#f9321c', 'redstone_torch', 'redstone_wall_torch');
    setLightColorEx('#26758d', 'sculk_catalyst');
    setLightColorEx('#8bdff8', 'sea_lantern');
    setLightColorEx('#4d9a76', 'sea_pickle');
    setLightColorEx('#918f34', 'shroomlight');
    setLightColorEx('#f39e49', 'smoker');
    setLightColorEx('#28aaeb', 'soul_campfire');
    setLightColorEx('#28aaeb', 'soul_fire');
    setLightColorEx('#28aaeb', 'soul_lantern');
    setLightColorEx('#28aaeb', 'soul_torch', 'soul_wall_torch');
    setLightColorEx('#f3b549', 'torch', 'wall_torch');
    setLightColorEx('#a61914', 'trial_spawner');
    setLightColorEx('#dfb906', 'vault');
    setLightColorEx('#63e53c', 'copper_torch', 'copper_wall_torch');

    // Modded blocks
    setLightColorEx('#df0606', 'mcwlights:red_paper_lamp');
    setLightColorEx('#df4706', 'mcwlights:orange_paper_lamp');
    setLightColorEx('#dfd406', 'mcwlights:yellow_paper_lamp');
    setLightColorEx('#8fdf06', 'mcwlights:lime_paper_lamp');
    setLightColorEx('#06df0a', 'mcwlights:green_paper_lamp');
    setLightColorEx('#06dfa5', 'mcwlights:cyan_paper_lamp');

    // Glass?
    setLightColorEx("#322638", "tinted_glass");
    setLightColorEx("#ffffff", "white_stained_glass", "white_stained_glass_pane");
    setLightColorEx("#999999", "light_gray_stained_glass", "light_gray_stained_glass_pane");
    setLightColorEx("#4c4c4c", "gray_stained_glass", "gray_stained_glass_pane");
    setLightColorEx("#191919", "black_stained_glass", "black_stained_glass_pane");
    setLightColorEx("#664c33", "brown_stained_glass", "brown_stained_glass_pane");
    setLightColorEx("#993333", "red_stained_glass", "red_stained_glass_pane");
    setLightColorEx("#d87f33", "orange_stained_glass", "orange_stained_glass_pane");
    setLightColorEx("#e5e533", "yellow_stained_glass", "yellow_stained_glass_pane");

    setLightColorEx("#7fcc19", "lime_stained_glass", "lime_stained_glass_pane");
    setLightColorEx("#667f33", "green_stained_glass", "green_stained_glass_pane");
    setLightColorEx("#4c7f99", "cyan_stained_glass", "cyan_stained_glass_pane");
    setLightColorEx("#6699d8", "light_blue_stained_glass", "light_blue_stained_glass_pane");
    setLightColorEx("#334cb2", "blue_stained_glass", "blue_stained_glass_pane");
    setLightColorEx("#7f3fb2", "purple_stained_glass", "purple_stained_glass_pane");
    setLightColorEx("#b24cd8", "magenta_stained_glass", "magenta_stained_glass_pane");
    setLightColorEx("#f27fa5", "pink_stained_glass", "pink_stained_glass_pane");

    // Candles
    if (coloredCandles) {
        setLightColorEx("#c07047", "candle");
        setLightColorEx("#ffffff", "white_candle");
        setLightColorEx("#bbbbbb", "light_gray_candle");
        setLightColorEx("#696969", "gray_candle");
        setLightColorEx("#1f1f1f", "black_candle");
        setLightColorEx("#8f5b35", "brown_candle");
        setLightColorEx("#b53129", "red_candle");
        setLightColorEx("#ff8118", "orange_candle");
        setLightColorEx("#ffcc4b", "yellow_candle");
        setLightColorEx("#7bc618", "lime_candle");
        setLightColorEx("#608116", "green_candle");
        setLightColorEx("#129e9d", "cyan_candle");
        setLightColorEx("#29a1d5", "light_blue_candle");
        setLightColorEx("#455abe", "blue_candle");
        setLightColorEx("#832cb4", "purple_candle");
        setLightColorEx("#bd3cb4", "magenta_candle");
        setLightColorEx("#f689ac", "pink_candle");
    }
    else {
        setLightColorEx("#c07047", "candle", "white_candle", "light_gray_candle", "gray_candle", "black_candle",
            "brown_candle", "red_candle", "orange_candle", "yellow_candle", "lime_candle", "green_candle", "cyan_candle",
            "light_blue_candle", "blue_candle", "purple_candle", "magenta_candle", "pink_candle");
    }
}

export function hexToRgb(hex: string) {
    const bigint = parseInt(hex.substring(1), 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    return {r, g, b};
}

export function setLightColorEx(hex: string, ...blocks: string[]) {
    const color = hexToRgb(hex);
    blocks.forEach(block => setLightColor(new NamespacedId(block), color.r, color.g, color.b, 255));
}