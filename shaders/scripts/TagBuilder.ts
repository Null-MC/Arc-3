export class TagBuilder {
    private pipeline : PipelineConfig;
    private exports: ExportList;
    private index: number = 0;

    constructor(pipeline : PipelineConfig, exports: ExportList) {
        this.pipeline = pipeline;
        this.exports = exports;
    }

    map(name: string, namespace: NamespacedId): TagBuilder {
        if (this.index >= 32) throw new RangeError('Limit of 32 tags has been exceeded!');

        this.pipeline.addTag(this.index, namespace);
        this.exports.addInt(name, (1 << this.index));
        this.index++;

        return this;
    }
}
