// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import "../theme"

Image {
    id: root

    required property string glyph

    width: 32 * Theme.scale
    height: 32 * Theme.scale
    sourceSize.width: 26
    sourceSize.height: 26
    fillMode: Image.PreserveAspectFit
    smooth: false
    mipmap: false
    asynchronous: false

    source: {
        switch (glyph.toLowerCase()) {
        case "a": return "qrc:/shulk/controller/a.png"
        case "b": return "qrc:/shulk/controller/b.png"
        case "x": return "qrc:/shulk/controller/x.png"
        case "y": return "qrc:/shulk/controller/y.png"
        case "menu": return "qrc:/shulk/controller/menu.png"
        case "lb": return "qrc:/shulk/controller/lb.png"
        case "rb": return "qrc:/shulk/controller/rb.png"
        case "lt": return "qrc:/shulk/controller/lt.png"
        case "rt": return "qrc:/shulk/controller/rt.png"
        default: return ""
        }
    }
}
