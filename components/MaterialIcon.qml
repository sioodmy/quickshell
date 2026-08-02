import QtQuick

StyledText {
    id: root
    property string icon: "settings"
    property int fill: 0
    property int grade: 0
    property int opticalSize: 24

    text: root.icon
    font.family: "Material Symbols Rounded"
    font.variableAxes: ({
        "FILL": root.fill,
        "GRAD": root.grade,
        "opsz": root.opticalSize
    })
}
