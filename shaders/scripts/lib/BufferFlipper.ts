export class BufferFlipper {
    isAlt: boolean
    textureA: BuiltTexture;
    textureB: BuiltTexture;

    constructor(textureA: BuiltTexture, textureB: BuiltTexture) {
        this.textureA = textureA;
        this.textureB = textureB;
        this.isAlt = false;
    }

    flip(): void {
        this.isAlt = !this.isAlt;
    }

    getReadTexture(): BuiltTexture {
        return this.isAlt ? this.textureA : this.textureB;
    }

    getWriteTexture(): BuiltTexture {
        return this.isAlt ? this.textureB : this.textureA;
    }
}
