(function() {
class UtilsInterface {
    /**
     * @param {WasmMemoryInterface} mem
     */
    constructor(mem) {
        this.mem = mem;
    }

    getInterface() {
        return {
            js_load_file_sync: (pathPtr, pathLen, bufferPtr, bufferSize) => {
                const path = this.mem.loadString(pathPtr, pathLen);

                try {
                    const xhr = new XMLHttpRequest();
                    xhr.open('GET', path, false); // false = synchronous
                    xhr.overrideMimeType('text/plain; charset=x-user-defined');
                    xhr.send();

                    if (xhr.status === 200) {
                        const responseText = xhr.responseText;
                        const bytes = new Uint8Array(responseText.length);
                        for (let i = 0; i < responseText.length; i++) {
                            bytes[i] = responseText.charCodeAt(i) & 0xff;
                        }

                        if (bytes.byteLength > bufferSize) {
                            console.error(`File too large: ${bytes.byteLength} > ${bufferSize}`);
                            return -1;
                        }

                        const targetBuffer = new Uint8Array(
                            this.mem.mem.buffer,
                            bufferPtr,
                            bytes.byteLength
                        );

                        targetBuffer.set(bytes);

                        return bytes.byteLength;
                    }

                    console.error(`HTTP ${xhr.status} loading ${path}`);
                    return -1;

                } catch (e) {
                    console.error(`Error loading ${path}:`, e);
                    return -1;
                }
            }
        }
    } // getInterface
}

window.odin = window.odin || {};
window.odin.UtilsInterface = UtilsInterface;
})();
