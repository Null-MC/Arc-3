export class FloodFill {
    private texFloodFillA: BuiltTexture;
    private texFloodFillB: BuiltTexture;
    private reader: ActiveTextureReference;
    private writer: ActiveTextureReference;

    
    constructor(pipeline: PipelineConfig, size: number) {
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

    create(stage: CommandList, size: number): Compute {
        return stage.createCompute("floodfill")
            .location("pre/floodfill", "floodfill")
            .workGroups(
                Math.ceil(size / 8),
                Math.ceil(size / 8),
                Math.ceil(size / 8));
    }

    update(altFrame: boolean) {
        this.reader.pointTo(altFrame ? this.texFloodFillA : this.texFloodFillB);
        this.writer.pointTo(altFrame ? this.texFloodFillB : this.texFloodFillA);
    }
}
