export class FloodFill_Sky {
    private texFloodFill_SkyA: BuiltTexture;
    private texFloodFill_SkyB: BuiltTexture;
    private reader: ActiveTextureReference;
    private writer: ActiveTextureReference;

    static BufferSizeXZ: number = 128;
    static BufferSizeY: number = 256;
    
    constructor(pipeline: PipelineConfig) {
        this.texFloodFill_SkyA = pipeline.createImageTexture('texFloodFill_SkyA', 'imgFloodFill_SkyA')
            .format(Format.R16F)
            .width(FloodFill_Sky.BufferSizeXZ)
            .height(FloodFill_Sky.BufferSizeY)
            .depth(FloodFill_Sky.BufferSizeXZ)
            .clear(false)
            .build();

        this.texFloodFill_SkyB = pipeline.createImageTexture('texFloodFill_SkyB', 'imgFloodFill_SkyB')
            .format(Format.R16F)
            .width(FloodFill_Sky.BufferSizeXZ)
            .height(FloodFill_Sky.BufferSizeY)
            .depth(FloodFill_Sky.BufferSizeXZ)
            .clear(false)
            .build();

        this.reader = pipeline.createTextureReference('texFloodFill_Sky_read', 'imgFloodFill_Sky_read', FloodFill_Sky.BufferSizeXZ, FloodFill_Sky.BufferSizeY, FloodFill_Sky.BufferSizeXZ, Format.R16F);
        this.writer = pipeline.createTextureReference('texFloodFill_Sky_write', 'imgFloodFill_Sky_write', FloodFill_Sky.BufferSizeXZ, FloodFill_Sky.BufferSizeY, FloodFill_Sky.BufferSizeXZ, Format.R16F);
    }

    build(stage: CommandList) {
        stage.createCompute("floodfill-sky-spread")
            .location("pre/floodfill-sky", "floodfill_sky_spread")
            .workGroups(
                Math.ceil(FloodFill_Sky.BufferSizeXZ / 8),
                Math.ceil(FloodFill_Sky.BufferSizeY / 4),
                Math.ceil(FloodFill_Sky.BufferSizeXZ / 8))
            .compile();

        stage.createCompute("floodfill-sky-visibility")
            .location("pre/floodfill-sky", "floodfill_sky")
            .workGroups(
                Math.ceil(FloodFill_Sky.BufferSizeXZ),
                Math.ceil(1),
                Math.ceil(FloodFill_Sky.BufferSizeXZ))
            .compile();
    }

    update(altFrame: boolean) {
        this.reader.pointTo(altFrame ? this.texFloodFill_SkyA : this.texFloodFill_SkyB);
        this.writer.pointTo(altFrame ? this.texFloodFill_SkyB : this.texFloodFill_SkyA);
    }
}
