// The hero's "Ponlo en tu mesa" button: the 3D logo in augmented reality.

import JavaScriptKit

// canonicalWebPageURL: sharing from Quick Look shares the web, not the .usdz file.
let quickLookModel = "/assets/3d/hola-swift-3d.usdz#canonicalWebPageURL=https://holaswift.com/"
// Scene Viewer downloads the model itself, so it needs the absolute URL. Without ARCore it opens it in 3D.
let sceneViewerIntent = "intent://arvr.google.com/scene-viewer/1.2?file=https://holaswift.com/assets/3d/hola-swift-3d.glb&mode=ar_preferred&title=hola%20Swift#Intent;scheme=https;package=com.google.android.googlequicksearchbox;action=android.intent.action.VIEW;S.browser_fallback_url=https%3A%2F%2Fholaswift.com%2F;end;"

func setUpAR() {
    let button = byId("ar")
    guard button.object != nil else { return }
    let quickLook = document.createElement("a").relList.supports("ar").boolean ?? false
    let android = JSValue.object(global.RegExp.object!.new("Android")).test(global.navigator.userAgent).boolean ?? false
    // Elsewhere the link would download the .usdz: the button stays hidden, as it comes in the HTML.
    guard quickLook || android else { return }
    button.hidden = .boolean(false)
    listen(button, "click") { _ in
        if quickLook { openQuickLook() } else { global.location.href = .string(sceneViewerIntent) }
    }
}

/// Safari only hands a link to Quick Look if it has `rel="ar"` and an image inside, so the button builds one and taps it.
func openQuickLook() {
    let link = document.createElement("a")
    _ = link.setAttribute("rel", "ar")
    _ = link.setAttribute("href", quickLookModel)
    _ = link.appendChild(document.createElement("img"))
    _ = link.click()
}
