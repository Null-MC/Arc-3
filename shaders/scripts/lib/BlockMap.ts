export class BlockMeta {
    blocks: string[]
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

    map(define: string, ...blocks: string[]) : BlockMap {
        const meta = new BlockMeta();
        meta.index = ++this.index;
        meta.blocks = blocks;
        meta.define = define;

        for (const block of blocks)
            this.mappings[block] = meta;

        this.exports.addInt(meta.define, meta.index);
        return this;
    }

    get(block: string) : BlockMeta | undefined {
        return this.mappings[block];
    }
}
