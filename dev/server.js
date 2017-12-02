const webpack = require('webpack');
const webpackDevMiddleware = require('webpack-dev-middleware');
const webpackHotMiddleware = require('webpack-hot-middleware');
const { createProxyServer } = require('http-proxy');
const { join } = require('path');
const { createServer } = require('http');
const express = require('express');
const publicRouteMiddleware = require('./publicRouteMiddleware');

const ROOT = join(__dirname, '..');

const app = express();

// Serve up index.html for the frontend routes
app.use(publicRouteMiddleware());

const port = process.env.PORT || 3000;

// Cause the whole process to crash when we have an unhandled promise
// Otherwise we might not notice them very easily
process.on('unhandledRejection', error => {
  throw error;
});

const USE_DIST = process.argv.indexOf('--use-dist') !== -1;

if (USE_DIST) {
  // We just serve whatever files are built
  // You need to have run the build first or dist will be empty
  // This is for trying out the production build locally

  console.log('serving static files from dist');
  app.use(express.static(join(ROOT, 'dist')));
} else {
  // We want to serve up the latest webpack files and do all the cool stuff
  // watch for changes, do hot module replacement, etc...

  const webpackConfig = require('./webpack.development.config');
  const compiler = webpack(webpackConfig);

  const devMiddleware = webpackDevMiddleware(compiler, {
    publicPath: webpackConfig.output.publicPath,
    quiet: true
  });

  const hotMiddleware = webpackHotMiddleware(compiler, {
    log: () => {}
  });

  app.use(devMiddleware);
  app.use(hotMiddleware);

  // force page reload when html-webpack-plugin template changes
  compiler.plugin('compilation', compilation => {
    compilation.plugin('html-webpack-plugin-after-emit', (data, done) => {
      hotMiddleware.publish({ action: 'reload' });
      done();
    });
  });
}

// Proxy all other requests to the dev site (e.g. /api)

const proxy = createProxyServer({
  changeOrigin: true,
  hostRewrite: true,
  autoRewrite: true,
  protocolRewrite: true,
  cookieDomainRewrite: true
});

app.use((req, res, next) => {
  proxy.web(req, res, {
    target: 'https://dev.ilovefreegle.org'
  });
});

app.listen(port, () => {
  console.log(`listening at http://localhost:${port}`);
});
