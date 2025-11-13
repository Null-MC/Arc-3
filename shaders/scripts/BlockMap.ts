export class BlockMeta {
    block: string
    define: string
    index: number
}

export class BlockMap {
    private exports: ExportList;
    private mappings: Record<string, BlockMeta> = {};
    private index: number = 0;


    constructor(exports: ExportList) {
        this.exports = exports;
    }

    map(block: string, define: string) : BlockMap {
        const meta = new BlockMeta();
        meta.index = ++this.index;
        meta.block = block;
        meta.define = define;

        this.mappings[block] = meta;
        this.exports.addInt(meta.define, meta.index);
        return this;
    }

    get(block: string) : BlockMeta | undefined {
        return this.mappings[block];
    }
}
