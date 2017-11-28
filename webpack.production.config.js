const HtmlWebpackPlugin = require('html-webpack-plugin');
const FaviconsPlugin = require('favicons-webpack-plugin');
const webpack = require('webpack');
var wc = require('webpack-config');
var Config = wc.Config;

exports['default'] = new Config().extend('webpack.base.config.js').merge({
    plugins: [
        new FaviconsPlugin('images/user_logo.png'),
        new webpack.DefinePlugin({
            CHAT_HOST: JSON.stringify('https://www.ilovefreegle.org'),
            EVENT_HOST: JSON.stringify('https://dev.ilovefreegle.org'),
            API: JSON.stringify('https://www.ilovefreegle.org/api/'),
            FACEBOOK_APPID: JSON.stringify('134980666550322'),
            FACEBOOK_GRAFFITI_APPID: JSON.stringify('115376591981611'),
            GOOGLE_CLIENT_ID: JSON.stringify('423761283916-1rpa8120tpudgv4nf44cpmlf8slqbf4f.apps.googleusercontent.com'),
            USER_SITE: JSON.stringify('www.ilovefreegle.org'),
            SITE_NAME: JSON.stringify('Freegle'),
            SITE_DESCRIPTION: JSON.stringify('Give and get stuff for free in your local community.  Don\'t just recycle - reuse, freecycle and freegle!'),
        }),
        new HtmlWebpackPlugin({
            hash: true,
            title: 'Freegle',
            template: './client/index.html',
            filename: 'index.html',
            logo: 'https://www.ilovefreegle.org/images/user_logo.png',
            url: 'https://www.ilovefreegle.org'
        }),
    ]
});