// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import {Socket} from "phoenix"
import NProgress from "nprogress"
import {LiveSocket} from "phoenix_live_view"

import jQuery from "jquery"
import select2 from "select2"
import "select2/dist/css/select2.css"

// see https://www.poeticoding.com/phoenix-liveview-javascript-hooks-and-select2/
// for the liveview select2 example I used

let Hooks = {}
Hooks.SelectModules = {
  initButton() {
    let hook = this,
        $select1 = jQuery(hook.el).find("#module_1"),
        $select2 = jQuery(hook.el).find("#module_2"),
        $button = jQuery(hook.el).find("button");

    $select1.select2();
    $select2.select2();

    $button.click(() => hook.pressed(hook, $select1, $select2));
    return $button;
  },

  mounted() {
    this.initButton();
  },

  pressed(hook, select1, select2) {
    let data = [
      select1.select2('data'),
      select2.select2('data')
    ].flat();

    hook.pushEvent("modules-selected", {modules: data})
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
