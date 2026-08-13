// The PDF page cache.
//
// `makePDF` used to hold every page a reader visited in an unbounded `Map` and
// never call `revokeObjectURL`, so a long document grew heavier the further
// into it you read. These tests pin the three properties that fix depends on:
// the cache is bounded, eviction gives back BOTH blob URLs a page holds, and
// two callers wanting the same page render it once.
//
// Run with `npm test` from `assets/foliate-js`.

import assert from 'node:assert/strict'
import test from 'node:test'

// ---------------------------------------------------------------- environment

// `pdf.js` is written against a browser. Nothing here tries to be a real DOM -
// it is the smallest surface the module actually touches, instrumented so the
// tests can count renders and URL lifetimes.
const install = () => {
    const state = {
        live: new Set(),
        revoked: [],
        created: 0,
        rendered: [],
    }

    let nextId = 0
    globalThis.URL = {
        createObjectURL() {
            const url = `blob:${nextId++}`
            state.live.add(url)
            state.created++
            return url
        },
        revokeObjectURL(url) {
            state.live.delete(url)
            state.revoked.push(url)
        },
    }

    globalThis.innerWidth = 400
    globalThis.innerHeight = 800
    globalThis.devicePixelRatio = 3

    globalThis.document = {
        createElement(tag) {
            if (tag !== 'canvas') return { classList: { add() {} }, outerHTML: '' }
            return {
                width: 0,
                height: 0,
                getContext: () => ({}),
                // The module probes for WebP before it encodes anything.
                toDataURL: () => 'data:image/webp;base64,AA==',
                toBlob(callback) { callback(new Blob(['page'])) },
            }
        },
    }

    globalThis.pdfjsLib = {
        renderTextLayer: () => ({ promise: Promise.resolve() }),
        AnnotationLayer: class {
            render() { return Promise.resolve() }
        },
    }

    return state
}

// A document whose pages resolve immediately, counting every rasterise.
const fakePdf = (numPages, state) => ({
    numPages,
    getMetadata: async () => ({ info: { Title: 't', Author: 'a' } }),
    getOutline: async () => null,
    getPage: async n => {
        state.rendered.push(n - 1)
        return {
            getViewport: ({ scale }) => ({ width: 100 * scale, height: 200 * scale }),
            render: () => ({ promise: Promise.resolve() }),
            getTextContent: async () => ({ items: [] }),
            getAnnotations: async () => [],
        }
    },
    destroy() { state.destroyed = true },
})

const load = async (numPages = 400) => {
    const state = install()
    // Prefetch runs on idle. Make that a macrotask the tests can flush, rather
    // than leaving it to a timeout they would have to sleep through.
    const idleQueue = []
    globalThis.requestIdleCallback = fn => idleQueue.push(fn)

    globalThis.pdfjsLib.getDocument = () => ({
        promise: Promise.resolve(fakePdf(numPages, state)),
    })

    // Import fresh each time: the module holds the WebP probe result.
    const { makePDF } = await import(`../src/pdf.js?case=${Math.random()}`)
    const book = await makePDF({ arrayBuffer: async () => new ArrayBuffer(8) })

    const flushIdle = async () => {
        while (idleQueue.length) await idleQueue.shift()()
        // Let the renders those callbacks started settle.
        await new Promise(resolve => setTimeout(resolve, 0))
    }
    return { book, state, flushIdle }
}

// --------------------------------------------------------------------- tests

test('a long read does not grow without bound', async () => {
    const { book, state, flushIdle } = await load(400)

    for (let i = 0; i < 60; i++) {
        await book.sections[i].load()
        await flushIdle()
    }

    // Two URLs per resident page: the document and the image inside it.
    assert.ok(state.live.size <= 10 * 2,
        `expected at most 20 live blob URLs, found ${state.live.size}`)
    assert.ok(state.revoked.length > 0, 'eviction never revoked anything')
    // Everything created is either still resident or given back. Nothing leaks.
    assert.equal(state.created, state.live.size + state.revoked.length)
})

test('eviction gives back both URLs a page holds', async () => {
    const { book, state, flushIdle } = await load(400)

    for (let i = 0; i < 40; i++) {
        await book.sections[i].load()
        await flushIdle()
    }

    // An odd count would mean a page was dropped holding one of its two URLs -
    // and the one most likely to survive is the image, which is the large one.
    assert.equal(state.revoked.length % 2, 0,
        'a page was evicted without both of its URLs being revoked')
})

test('the page being read is never the page evicted', async () => {
    const { book, state, flushIdle } = await load(400)

    for (let i = 0; i < 40; i++) {
        const url = await book.sections[i].load()
        await flushIdle()
        assert.ok(state.live.has(url),
            `page ${i} was revoked while it was the page on screen`)
    }
})

test('two callers wanting the same page render it once', async () => {
    const { book, state } = await load(400)

    const [a, b, c] = await Promise.all([
        book.sections[7].load(),
        book.sections[7].load(),
        book.sections[7].load(),
    ])

    assert.equal(a, b)
    assert.equal(b, c)
    assert.deepEqual(state.rendered.filter(i => i === 7), [7],
        'the same page was rasterised more than once')
})

test('turning back to a cached page does not render it again', async () => {
    const { book, state, flushIdle } = await load(400)

    await book.sections[3].load()
    await flushIdle()
    const before = state.rendered.length
    await book.sections[3].load()

    assert.equal(state.rendered.length, before,
        'a cache hit still went through the renderer')
})

test('neighbours are rendered ahead', async () => {
    const { book, state, flushIdle } = await load(400)

    await book.sections[10].load()
    assert.deepEqual(state.rendered, [10], 'prefetch ran on the turn itself')

    await flushIdle()
    assert.ok(state.rendered.includes(11), 'the next page was not prefetched')
    assert.ok(state.rendered.includes(9), 'the previous page was not prefetched')
})

test('prefetch stops at the ends of the document', async () => {
    const { book, flushIdle } = await load(3)

    await book.sections[0].load()
    await flushIdle()
    await book.sections[2].load()
    await flushIdle()
    // Reaching for page -1 or page 3 would have thrown by now.
})

test('destroy gives back every page still resident', async () => {
    const { book, state, flushIdle } = await load(400)

    for (let i = 0; i < 5; i++) {
        await book.sections[i].load()
        await flushIdle()
    }
    book.destroy()

    assert.equal(state.live.size, 0, 'pages were still held after destroy')
    assert.ok(state.destroyed, 'the pdf.js document was not destroyed')
})
