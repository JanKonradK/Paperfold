const path = require('path');

module.exports = {
  entry: {
    bundle: ['core-js/stable', './src/book.js']
  },
  output: {
    clean: true,
    filename: '[name].js',
    path: path.resolve(__dirname, 'dist'),
    // The Flutter WebView loads a single browser bundle.
    library: {
      name: 'FoliateJS',
      type: 'umd',
      export: 'default'
    },
    globalObject: '(typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : typeof global !== "undefined" ? global : this)'
  },
  mode: 'production',
  target: ['web', 'es2017'], // Webpack's async-module runtime needs native async/await.
  optimization: {
    splitChunks: false,
    runtimeChunk: false,
    minimize: true
  },
  performance: {
    hints: false
  },
  experiments: {
    outputModule: false
  },
  resolve: {
    fallback: {
      // Disable Node.js polyfills for browser build
      "fs": false,
      "zlib": false,
      "http": false,
      "https": false,
      "url": false,
      "canvas": false,
      "util": false,
      "stream": false,
      "buffer": false,
      "crypto": false,
      "os": false,
      "path": false
    }
  },
  module: {
    parser: {
      javascript: {
        dynamicImportMode: 'eager'
      }
    },
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: 'babel-loader'
      }
    ]
  }
};
