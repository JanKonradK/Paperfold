// `FixedLayout` is the renderer behind PDF, CBZ and fixed-layout EPUB. It never
// received any of the page-turn work the reflowable `Paginator` did, and it
// rebuilt its whole DOM on every turn.
//
// These tests pin the turn path: frames are reused rather than rebuilt, a turn
// that overtakes another does not let the slower one report the page it landed
// on, and a section that owns resources is released once the reader has moved
// well past it - but not the instant they turn away from it.
//
// Run with `npm test` from `assets/foliate-js`.

import assert from 'node:assert/strict'
import test from 'node:test'

// ---------------------------------------------------------------- environment

// The smallest DOM `FixedLayout` actually touches. Iframe navigation is
// modelled honestly: assigning `src` fires `load` on a later turn of the
// microtask queue, which is what lets a second turn overtake a first.
const installDom = () => {
    const counts = { iframes: 0, divs: 0 }

    class FakeNode {
        constructor(tag) {
            this.tag = tag
            this.style = {}
            this.children = []
            this.attributes = {}
            this.listeners = new Map()
        }
        append(child) { this.children.push(child) }
        replaceChildren(...children) { this.children = children }
        setAttribute(name, value) { this.attributes[name] = value }
        addEventListener(type, fn) {
            if (!this.listeners.has(type)) this.listeners.set(type, new Set())
            this.listeners.get(type).add(fn)
        }
        removeEventListener(type, fn) { this.listeners.get(type)?.delete(fn) }
        emit(type) {
            for (const fn of [...(this.listeners.get(type) ?? [])]) fn()
        }
        querySelectorAll() { return [] }
    }

    class FakeIframe extends FakeNode {
        #src = null
        constructor() {
            super('iframe')
            // A never-navigated iframe still has an about:blank document.
            this.contentDocument = { position: null, scale: null }
            this.loadDelay = 0
        }
        get src() { return this.#src }
        set src(value) {
            this.#src = value
            // A fresh document per navigation, as a real iframe gives.
            const settle = () => {
                this.contentDocument = {
                    position: null,
                    scale: null,
                    documentElement: { localName: 'html' },
                    querySelector: selector => selector.includes('viewport')
                        ? { getAttribute: () => 'width=800, height=1200' }
                        : null,
                }
                this.emit('load')
            }
            if (this.loadDelay) setTimeout(settle, this.loadDelay)
            else queueMicrotask(settle)
        }
    }

    globalThis.document = {
        createElement(tag) {
            if (tag === 'iframe') { counts.iframes++; return new FakeIframe() }
            counts.divs++
            return new FakeNode(tag)
        },
    }
    globalThis.CSSStyleSheet = class { replaceSync() {} }
    globalThis.ResizeObserver = class {
        observe() {} unobserve() {}
    }
    globalThis.CustomEvent = class extends Event {
        constructor(type, init) { super(type); this.detail = init?.detail }
    }
    globalThis.customElements = { define() {} }
    globalThis.HTMLElement = class extends EventTarget {
        #shadow
        attachShadow() {
            this.#shadow = new FakeNode('shadow')
            this.shadowForTest = this.#shadow
            return this.#shadow
        }
        // Portrait, so a two-page spread shows one page at a time - the shape
        // the application is actually designed for.
        getBoundingClientRect() { return { width: 400, height: 800 } }
    }

    return counts
}

// A book of `pages` single-page sections. `owned` sections define `unload`, the
// way a CBZ page does; the rest define none, the way a PDF page does, because
// pdf.js holds its own bounded cache.
const makeBook = (pages, { owned = false } = {}) => {
    const unloaded = []
    const sections = Array.from({ length: pages }, (_, i) => {
        const section = {
            id: i,
            load: async () => `blob:page-${i}`,
            size: 1000,
        }
        if (owned) section.unload = () => unloaded.push(i)
        return section
    })
    // One page per spread, which is what pdf.js asks for via `spread: 'none'`.
    return { book: { sections, rendition: { spread: 'none' } }, unloaded }
}

const mount = async (pages, options) => {
    const counts = installDom()
    const { FixedLayout } = await import(`../src/fixed-layout.js?case=${Math.random()}`)
    const { book, unloaded } = makeBook(pages, options)
    const element = new FixedLayout()
    element.open(book)
    return { element, counts, unloaded, book }
}

const settle = () => new Promise(resolve => setTimeout(resolve, 5))

// --------------------------------------------------------------------- tests

test('turning pages reuses the frames instead of rebuilding them', async () => {
    const { element, counts } = await mount(50)

    await element.goTo({ index: 0 })
    for (let i = 0; i < 20; i++) await element.next()
    await settle()

    // Two slots, made once. This used to be two fresh iframes per turn.
    assert.equal(counts.iframes, 2,
        `expected 2 iframes for the whole read, ${counts.iframes} were created`)
})

test('a turn that overtakes another does not report the page it left', async () => {
    const { element } = await mount(50)
    await element.goTo({ index: 0 })

    const reported = []
    element.addEventListener('load', e => reported.push(e.detail.index))

    // Make the first turn slow, then start a second before it settles.
    element.shadowForTest.children
        .flatMap(child => child.children)
        .forEach(iframe => { iframe.loadDelay = 20 })

    const slow = element.goTo({ index: 10 })
    const fast = element.goTo({ index: 20 })
    await Promise.all([slow, fast])
    await settle()

    assert.ok(!reported.includes(10),
        'the overtaken turn still announced its document')
    assert.ok(reported.includes(20), 'the turn that won never announced')
})

test('a section that owns resources survives turning back', async () => {
    const { element, unloaded } = await mount(50, { owned: true })

    await element.goTo({ index: 0 })
    await element.next()
    await element.prev()
    await settle()

    assert.deepEqual(unloaded, [],
        'a page was released while the reader was still next to it')
})

test('a section that owns resources is released once well behind', async () => {
    const { element, unloaded } = await mount(50, { owned: true })

    await element.goTo({ index: 0 })
    for (let i = 0; i < 12; i++) await element.next()
    await settle()

    assert.ok(unloaded.length > 0, 'nothing was ever released across 12 turns')
    assert.ok(unloaded.includes(0), 'the first page was never released')
    // Everything released is well behind the reader, never the current page.
    assert.ok(!unloaded.includes(12), 'the current page was released')
})

test('a section with no unload is left alone', async () => {
    // The PDF case. pdf.js owns its own eviction; the renderer must not also
    // try to manage it.
    const { element, book } = await mount(50)
    for (const section of book.sections)
        assert.equal(section.unload, undefined)

    await element.goTo({ index: 0 })
    for (let i = 0; i < 12; i++) await element.next()
    await settle()
    // Reaching for a missing `unload` would have thrown by now.
})

test('destroy releases everything still held', async () => {
    const { element, unloaded } = await mount(50, { owned: true })

    await element.goTo({ index: 0 })
    await element.next()
    await settle()
    element.destroy()

    assert.ok(unloaded.includes(0) && unloaded.includes(1),
        `both visited pages should be released, got ${unloaded}`)
})

test('getContents reports only what is on screen', async () => {
    const { element } = await mount(50)

    await element.goTo({ index: 0 })
    await element.next()
    await settle()

    const contents = element.getContents()
    assert.equal(contents.length, 1, 'a hidden slot was reported as content')
    assert.equal(contents[0].index, 1,
        'the page reported was not the page on screen')
})
