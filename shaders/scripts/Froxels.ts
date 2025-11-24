export class Froxels {
    private texFroxelA: BuiltTexture;
    private texFroxelB: BuiltTexture;
    public reader: ActiveTextureReference;
    public writer: ActiveTextureReference;

    public BufferWidth;
    public BufferHeight;
    public BufferDepth;

    
    constructor(pipeline: PipelineConfig, screenWidth: number, screenHeight: number) {
        this.BufferWidth = Math.ceil(screenWidth / 8);
        this.BufferHeight = Math.ceil(screenHeight / 8);
        this.BufferDepth = 64;

        this.texFroxelA = pipeline.createImageTexture('texFroxelA', 'imgFroxelA')
            .format(Format.RGBA16F)
            .width(this.BufferWidth)
            .height(this.BufferHeight)
            .depth(this.BufferDepth)
            .clear(false)
            .build();

        this.texFroxelB = pipeline.createImageTexture('texFroxelB', 'imgFroxelB')
            .format(Format.RGBA16F)
            .width(this.BufferWidth)
            .height(this.BufferHeight)
            .depth(this.BufferDepth)
            .clear(false)
            .build();

        this.reader = pipeline.createTextureReference('texFroxel_read', 'imgFroxel_read', this.BufferWidth, this.BufferHeight, this.BufferDepth, Format.RGBA16F);
        this.writer = pipeline.createTextureReference('texFroxel_write', 'imgFroxel_write', this.BufferWidth, this.BufferHeight, this.BufferDepth, Format.RGBA16F);
    }

    create(stage: CommandList): Compute {
        return stage.createCompute("froxels")
            .location("composite/froxels", "updateFroxels")
            .workGroups(
                Math.ceil(this.BufferWidth / 8),
                Math.ceil(this.BufferHeight / 8),
                Math.ceil(this.BufferDepth / 4))
            .exportInt('Froxel_Width', this.BufferWidth)
            .exportInt('Froxel_Height', this.BufferHeight)
            .exportInt('Froxel_Depth', this.BufferDepth)
    }

    update(altFrame: boolean) {
        this.reader.pointTo(altFrame ? this.texFroxelA : this.texFroxelB);
        this.writer.pointTo(altFrame ? this.texFroxelB : this.texFroxelA);
    }
}
