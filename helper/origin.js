// Fork: where updates, compat.json and themes come from. Pinned here on purpose: D/source and config.json releasesUrl sit
// on /media/developer, which any app on a rooted TV can write, so they could point the updater at someone else's releases.
// The variable is only for tools/node8-check.js; the service's environment is set by our own boot scripts.
module.exports = { get REPO() { return process.env.CYTV_ORIGIN_REPO || 'sjelfull/cleanyourtv-WebOS'; }, REF: 'main' };
