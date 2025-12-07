import {BlockMap} from "./lib/BlockMap";
import {TagBuilder} from "./lib/TagBuilder";


export function MapBlocks(pipeline: PipelineConfig, id_map: BlockMap, tag_map: TagBuilder): void {
    id_map
        .map('BLOCK_WATER', 'water')
        .map('BLOCK_LAVA', 'lava');
        // .map('BLOCK_GLASS_TINTED', 'tinted_glass')
        // .map('BLOCK_GLASS_WHITE', 'white_stained_glass', 'white_stained_glass_pane')
        // .map('BLOCK_GLASS_LIGHT_GRAY', 'light_gray_stained_glass', 'light_gray_stained_glass_pane')
        // .map('BLOCK_GLASS_GRAY', 'gray_stained_glass', 'gray_stained_glass_pane')
        // .map('BLOCK_GLASS_BLACK', 'black_stained_glass', 'black_stained_glass_pane')
        // .map('BLOCK_GLASS_BROWN', 'brown_stained_glass', 'brown_stained_glass_pane')
        // .map('BLOCK_GLASS_RED', 'red_stained_glass', 'red_stained_glass_pane')
        // .map('BLOCK_GLASS_ORANGE', 'orange_stained_glass', 'orange_stained_glass_pane')
        // .map('BLOCK_GLASS_YELLOW', 'yellow_stained_glass', 'yellow_stained_glass_pane')
        // .map('BLOCK_GLASS_LIME', 'lime_stained_glass', 'lime_stained_glass_pane')
        // .map('BLOCK_GLASS_GREEN', 'green_stained_glass', 'green_stained_glass_pane')
        // .map('BLOCK_GLASS_CYAN', 'cyan_stained_glass', 'cyan_stained_glass_pane')
        // .map('BLOCK_GLASS_LIGHT_BLUE', 'light_blue_stained_glass', 'light_blue_stained_glass_pane')
        // .map('BLOCK_GLASS_BLUE', 'blue_stained_glass', 'blue_stained_glass_pane')
        // .map('BLOCK_GLASS_PURPLE', 'purple_stained_glass', 'purple_stained_glass_pane')
        // .map('BLOCK_GLASS_MAGENTA', 'magenta_stained_glass', 'magenta_stained_glass_pane')
        // .map('BLOCK_GLASS_PINK', 'pink_stained_glass', 'pink_stained_glass_pane');
    
    tag_map
        .map("TAG_LEAVES", new NamespacedId("minecraft", "leaves"))
        .map("TAG_STAIRS", new NamespacedId("minecraft", "stairs"))
        .map("TAG_SLABS", new NamespacedId("minecraft", "slabs"));
        // .map("TAG_SNOW", new NamespacedId("minecraft", "snow"));

    tag_map.map("TAG_TINTS_LIGHT", pipeline.createTag(new NamespacedId("arc", "tints_light"),
        new NamespacedId("minecraft", "glass_blocks"),
        new NamespacedId("tinted_glass"),
        new NamespacedId("white_stained_glass"),
        new NamespacedId("white_stained_glass_pane"),
        new NamespacedId("light_gray_stained_glass"),
        new NamespacedId("light_gray_stained_glass_pane"),
        new NamespacedId("gray_stained_glass"),
        new NamespacedId("gray_stained_glass_pane"),
        new NamespacedId("black_stained_glass"),
        new NamespacedId("black_stained_glass_pane"),
        new NamespacedId("brown_stained_glass"),
        new NamespacedId("brown_stained_glass_pane"),
        new NamespacedId("red_stained_glass"),
        new NamespacedId("red_stained_glass"),
        new NamespacedId("orange_stained_glass"),
        new NamespacedId("orange_stained_glass_pane"),
        new NamespacedId("yellow_stained_glass"),
        new NamespacedId("yellow_stained_glass_pane"),
        new NamespacedId("lime_stained_glass"),
        new NamespacedId("lime_stained_glass_pane"),
        new NamespacedId("green_stained_glass"),
        new NamespacedId("green_stained_glass_pane"),
        new NamespacedId("cyan_stained_glass"),
        new NamespacedId("cyan_stained_glass_pane"),
        new NamespacedId("light_blue_stained_glass"),
        new NamespacedId("light_blue_stained_glass_pane"),
        new NamespacedId("blue_stained_glass"),
        new NamespacedId("blue_stained_glass_pane"),
        new NamespacedId("purple_stained_glass"),
        new NamespacedId("purple_stained_glass_pane"),
        new NamespacedId("magenta_stained_glass"),
        new NamespacedId("magenta_stained_glass_pane"),
        new NamespacedId("pink_stained_glass"),
        new NamespacedId("pink_stained_glass_pane")));
    
    tag_map.map('TAG_WAVING_GROUND', pipeline.createTag(new NamespacedId('arc', 'foliage_ground'),
        new NamespacedId('acacia_sapling'),
        new NamespacedId('birch_sapling'),
        new NamespacedId('cherry_sapling'),
        new NamespacedId('jungle_sapling'),
        new NamespacedId('oak_sapling'),
        new NamespacedId('dark_oak_sapling'),
        new NamespacedId('pale_oak_sapling'),
        new NamespacedId('spruce_sapling'),
        new NamespacedId('allium'),
        new NamespacedId('azalea'),
        new NamespacedId('flowering_azalea'),
        new NamespacedId('azure_bluet'),
        new NamespacedId('beetroots'),
        new NamespacedId('blue_orchid'),
        new NamespacedId('bush'),
        new NamespacedId('cactus_flower'),
        new NamespacedId('carrots'),
        new NamespacedId('cornflower'),
        new NamespacedId('crimson_roots'),
        new NamespacedId('dead_bush'),
        new NamespacedId('dandelion'),
        new NamespacedId('open_eyeblossom'),
        new NamespacedId('closed_eyeblossom'),
        new NamespacedId('short_dry_grass'),
        new NamespacedId('tall_dry_grass'),
        new NamespacedId('fern'),
        new NamespacedId('firefly_bush'),
        new NamespacedId('grass'),
        new NamespacedId('short_grass'),
        new NamespacedId('lily_of_the_valley'),
        new NamespacedId('mangrove_propagule'),
        new NamespacedId('nether_sprouts'),
        new NamespacedId('orange_tulip'),
        new NamespacedId('oxeye_daisy'),
        new NamespacedId('pink_petals'),
        new NamespacedId('pink_tulip'),
        new NamespacedId('poppy'),
        new NamespacedId('potatoes'),
        new NamespacedId('red_tulip'),
        new NamespacedId('sweet_berry_bush'),
        new NamespacedId('torchflower'),
        new NamespacedId('torchflower_crop'),
        new NamespacedId('warped_roots'),
        new NamespacedId('wheat'),
        new NamespacedId('white_tulip'),
        new NamespacedId('wildflowers'),
        new NamespacedId('wither_rose')));

    tag_map.map('TAG_WAVING_FULL', pipeline.createTag(new NamespacedId('arc', 'waving_full'),
        new NamespacedId('azalea_leaves'),
        new NamespacedId('birch_leaves'),
        new NamespacedId('cherry_leaves'),
        new NamespacedId('flowering_azalea_leaves'),
        new NamespacedId('jungle_leaves'),
        new NamespacedId('mangrove_leaves'),
        new NamespacedId('oak_leaves'),
        new NamespacedId('dark_oak_leaves'),
        new NamespacedId('pale_oak_leaves'),
        new NamespacedId('spruce_leaves')));
}
