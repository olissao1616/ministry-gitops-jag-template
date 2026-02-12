
/**
 * @jest-environment node
 */

import { GET } from "./route";

async function readableStreamToString(readableStream: ReadableStream | null) {
    if (!readableStream) {
        return ''
    }
    const reader = readableStream.getReader();
    let result = '';
    let done = false;
  
    while (!done) {
      const { value, done: readDone } = await reader.read();
      if (readDone) {
        done = true;
      } else {
        result += new TextDecoder().decode(value);
      }
    }
  
    return result;
}

describe('/health API', () => {
  it('should return message UP!', async () => {
    const res = await GET();
    expect(res.status).toBe(200);
    const body = await readableStreamToString(res.body);
    expect(body).toBe("UP!");
  });
});
