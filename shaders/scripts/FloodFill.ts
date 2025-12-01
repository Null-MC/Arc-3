export class FloodFill {
    size: number;
    private texFloodFillA: BuiltTexture;
    private texFloodFillB: BuiltTexture;
    private reader: ActiveTextureReference;
    private writer: ActiveTextureReference;

    
    constructor(pipeline: PipelineConfig, size: number) {
        this.size = size;

        this.texFloodFillA = pipeline.createImageTexture('texFloodFillA', 'imgFloodFillA')
            .format(Format.RGBA16F)
            .width(size)
            .height(size)
            .depth(size)
            .clear(false)
            .build();

        this.texFloodFillB = pipeline.createImageTexture('texFloodFillB', 'imgFloodFillB')
            .format(Format.RGBA16F)
            .width(size)
            .height(size)
            .depth(size)
            .clear(false)
            .build();

        this.reader = pipeline.createTextureReference('texFloodFill_read', 'imgFloodFill_read', size, size, size, Format.RGBA16F);
        this.writer = pipeline.createTextureReference('texFloodFill_write', 'imgFloodFill_write', size, size, size, Format.RGBA16F);
    }

    build(stage: CommandList) {
        stage.createCompute("floodfill")
            .location("pre/floodfill", "floodfill")
            .workGroups(
                Math.ceil(this.size / 8),
                Math.ceil(this.size / 8),
                Math.ceil(this.size / 8))
            .compile();
    }

    update(altFrame: boolean) {
        this.reader.pointTo(altFrame ? this.texFloodFillA : this.texFloodFillB);
        this.writer.pointTo(altFrame ? this.texFloodFillB : this.texFloodFillA);
    }
}
