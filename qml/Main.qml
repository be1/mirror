/*
 * Copyright (C) 2020  Benoît Rouits
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * ubuntu-calculator-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7
import QtQml 2.2
import QtQuick.Window 2.2
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import QtMultimedia 5.9
import Ubuntu.Content 1.3
import TempPath 1.0

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'mirror.brouits'
    automaticOrientation: true

    anchors.fill: parent

    property var exportTransfer
    property list<ContentItem> snapshotItems
    property bool exportRequested

    Component {
        id: snapComponent
        ContentItem {}
    }

    Settings {
        id: settings
        property alias frame: frame.color
        property bool snapframe
        property alias unmirror: photoPreview.mirror
    }

    PageStack {
        id: pages
        anchors.fill: parent

        Component.onCompleted: pages.push(main)

        Page {
            id: main
            anchors.fill: parent
            visible: false

            header: PageHeader {
                id: header
                title: i18n.tr('Mirror')

                trailingActionBar.actions: [
                    Action {
                        iconName: "settings"
                        text: i18n.tr("Settings")
                        onTriggered: {
                            PopupUtils.open(dialog)
                        }
                    },
                    Action {
                        iconName: "filter"
                        text: i18n.tr("Filter")
                        property int index: 0
                        onTriggered: {
                            var len = camera.imageProcessing.supportedColorFilters.length
                            if (len) {
                                index = (index + 1) % len
                                camera.imageProcessing.colorFilter = camera.imageProcessing.supportedColorFilters[index]
                            }
                        }
                    }
                ]
            }

            Camera {
                id: camera
                position: Camera.FrontFace

                flash.mode: Camera.FlashOff
                imageProcessing.colorFilter: CameraImageProcessing.ColorFilterNone
                imageProcessing.whiteBalanceMode: CameraImageProcessing.WhiteBalanceAuto

                exposure {
                    exposureCompensation: -1.0
                    exposureMode: Camera.ExposurePortrait
                }

            }

            Rectangle {
                id: frame
                color: "pink"
                radius: units.gu(2)
                anchors {
                    top: header.bottom
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }

                border {
                    width: units.gu(2)
                    color: frame.color
                }

                VideoOutput {
                    id: videoOutput

                    anchors {
                        margins: units.gu(2)
                        fill: parent
                    }

                    autoOrientation: true
                    fillMode: VideoOutput.PreserveAspectCrop
                    source: camera
                    visible: !photoPreview.visible

                    PinchArea {
                        id: zoom
                        anchors.fill: parent
                        pinch.minimumScale: 0.1
                        pinch.maximumScale: 10
                        pinch.dragAxis: Pinch.XAndYAxis

                        onPinchUpdated: {
                            var optical = false

                            if (camera.maximumOpticalZoom > 1.0)
                                optical = true

                            if (pinch.scale > 0) {
                                var ratio
                                if (optical) {
                                    ratio = camera.maximumOpticalZoom / zoom.pinch.maximumScale
                                    camera.opticalZoom = pinch.scale * ratio
                                 } else {
                                    ratio = camera.maximumDigitalZoom / zoom.pinch.maximumScale
                                    camera.digitalZoom = pinch.scale * ratio
                                 }
                            } else {
                                if (optical) {
                                    camera.opticalZoom = pinch.previousScale
                                } else {
                                    camera.digitalZoom = pinch.previousScale
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                clock.visible = true
                                countTimer.start()
                            }
                        }
                    }
                }

                function captureStillImage() {
                    clock.visible = false
                    info.text = ""
                    snapshotItems = []
                    var snap = settings.snapframe ? frame : videoOutput
                    snap.grabToImage(function (result) {
                        var path = TempPath.path + "/mirror.jpg"
                        result.saveToFile(path)
                        photoPreview.source = result.url
                        info.text = i18n.tr("Share your Snapshot!")
                        photoPreview.visible = true
                        var item = snapComponent.createObject(root, {
                                                                  "url": path
                                                              })
                        snapshotItems.push(item)
                    })
                }
            }

            Image {
                id: photoPreview

                anchors {
                    top: header.bottom
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }

                fillMode: Image.PreserveAspectCrop
                visible: false

                Text {
                    id: info

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: units.gu(9)
                    }

                    font.pixelSize: units.gu(3)
                    font.bold: true
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        PopupUtils.open(yesno)
                    }
                }
            }

            Component {
                id: yesno
                Dialog {
                    id: confirmation

                    anchors {
                        fill: parent
                    }

                    title: i18n.tr("Confirm")
                    text: i18n.tr("Share this snapshot?")

                    Button {
                        text: i18n.tr("Yes")

                        onClicked: {
                            PopupUtils.close(confirmation)
                            photoPreview.visible = false
                            if (root.exportRequested) {
                                root.exportTransfer.items = snapshotItems
                                root.exportTransfer.state = ContentTransfer.Charged
                            } else if (snapshotItems.length > 0) {
                                pages.push(sharePage)
                            }
                        }
                    }

                    Button {
                        text: i18n.tr("No")
                        onClicked: {
                            PopupUtils.close(confirmation)
                            photoPreview.visible = false
                        }
                    }
                }
            }

            Clock {
                id: clock

                visible: false
                anchors.fill: parent

                text: countTimer.seconds

                onClicked: {
                    countTimer.stop()
                    clock.visible = false
                }
            }

            CountTimer {
                id: countTimer

                onTriggered: {
                    frame.captureStillImage()
                }
            }

            Component {
                id: dialog

                Dialog {
                    id: options
                    anchors {
                        fill: parent
                    }

                    title: i18n.tr("Preferences")

                    Label {
                        anchors.right: parent.right
                        text: i18n.tr("Include frame into snap")

                        Switch {
                            anchors.right: parent.right
                            checked: settings.snapframe

                            onCheckedChanged: settings.snapframe = checked
                        }
                    }

                    Label {
                        anchors.right: parent.right
                        text: i18n.tr("Unmirror snapshot")

                        Switch {
                            anchors.right: parent.right
                            checked: settings.unmirror

                            onCheckedChanged: settings.unmirror = checked
                        }
                    }

                    Label {
                        anchors.right: parent.right
                        text: i18n.tr("Choose a frame color")
                    }

                    Button {
                        text: "pink"
                        color: text

                        onClicked: {
                            settings.frame = color
                            PopupUtils.close(options)
                        }
                    }

                    Button {
                        text: "steelblue"
                        color: text

                        onClicked: {
                            settings.frame = color
                            PopupUtils.close(options)
                        }
                    }

                    Button {
                        text: "gray"
                        color: text

                        onClicked: {
                            settings.frame = color
                            PopupUtils.close(options)
                        }
                    }

                    Button {
                        text: "salmon"
                        color: text

                        onClicked: {
                            settings.frame = color
                            PopupUtils.close(options)
                        }
                    }

                    Button {
                        text: "violet"
                        color: text

                        onClicked: {
                            settings.frame = color
                            PopupUtils.close(options)
                        }
                    }

                    Button {
                        text: "seagreen"
                        color: text

                        onClicked: {
                            settings.frame = color
                            PopupUtils.close(options)
                        }
                    }
                }
            }
        }

        ContentPeerPicker {
            id: sharePage
            visible: false
            contentType: ContentType.Pictures
            handler: ContentHandler.Share

            onPeerSelected: {
                var transfer = peer.request()
                if (transfer.state === ContentTransfer.InProgress) {
                    transfer.items = snapshotItems
                    transfer.state = ContentTransfer.Charged
                }

                pages.pop()
            }

            onCancelPressed: pages.pop()
        }
    }

    Connections {
        target: ContentHub

        onExportRequested: {
            root.exportTransfer = transfer
            root.exportRequested = true
        }
    }
}
