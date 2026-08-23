import QtQuick 2.1
import FileIO 1.0
import qb.components 1.0
import qb.base 1.0

// Toon derives this exact component filename from the lowercase app folder.
App {
    id: matterBridgeApp

    property url tileUrl: "MatterBridgeTile.qml"
    property url screenUrl: "MatterBridgeScreen.qml"
    property url thumbnailIcon: "drawables/MatterBridgeIcon.svg"

    property variant knownDevices: []
    property variant selections: ({})
    property int catalogRevision: 0
    property int selectionRevision: 0
    property string catalogError: ""
    property string updatedAt: ""
    property bool bridgeRunning: false
    property bool commissioned: false
    property string bridgeMessage: "Matter-service nog niet actief"
    property string pairingCode: ""
    property string pairingQrImage: ""
    property bool energyAvailable: false
    property bool energyOnline: false
    property real energyImportW: 0
    property real energyExportW: 0
    property real energyNetW: 0
    property real gasFlowLph: 0

    function init() {
        registry.registerWidget("tile", tileUrl, this, "matterBridgeTile", {
            thumbLabel: "Matter Bridge",
            thumbIcon: thumbnailIcon,
            thumbCategory: "general",
            thumbWeight: 32,
            baseTileWeight: 12,
            thumbIconVAlignment: "center"
        })
        registry.registerWidget("screen", screenUrl, this, "matterBridgeDevices", {lazyLoadScreen: true})
    }

    Component.onCompleted: {
        requestInstall()
        loadSelections()
        refresh()
    }

    function requestInstall() {
        var pending = ""
        try { pending = tscCommandFile.read() } catch (error) {}
        if (pending.length === 0)
            tscCommandFile.write("external-matterbridge")
    }

    function loadSelections() {
        try {
            var document = JSON.parse(preferencesFile.read())
            selections = document.selected_devices || ({})
        } catch (error) {
            selections = ({})
        }
        selectionRevision++
    }

    function refresh() {
        refreshBridgeStatus()
        refreshCatalog()
    }

    function toonThermostatDevice() {
        return {
            id: "toon-thermostat",
            kind: "toon_thermostat",
            matter_type: "thermostat",
            name: "Toon thermostaat",
            detail: "Toon · Kamerthermostaat · Matter-thermostaat",
            online: true
        }
    }

    function refreshCatalog() {
        try {
            var envelope = JSON.parse(appBusStateFile.read())
            var state = envelope.state || envelope
            var devices = []
            devices.push(toonThermostatDevice())
            var climateDevices = state.devices || []
            for (var i = 0; i < climateDevices.length; i++) {
                var climate = climateDevices[i]
                if (climate.matter_eligible === true && climate.id && climate.name) {
                    devices.push({
                        id: String(climate.id),
                        kind: "climate",
                        matter_type: String(climate.matter_type || "thermostat"),
                        name: String(climate.name),
                        detail: climateDetail(climate),
                        online: climate.online === true
                    })
                }
            }

            var ventilation = state.ventilation || ({})
            if (ventilation.matter_eligible === true && ventilation.id && ventilation.name) {
                devices.push({
                    id: String(ventilation.id),
                    kind: "ventilation",
                    matter_type: String(ventilation.matter_type || "fan"),
                    name: String(ventilation.name),
                    detail: "Ventilatie · Matter-ventilator",
                    online: ventilation.online === true
                })
            }

            if (energyAvailable)
                devices.push(toonEnergyDevice())

            knownDevices = devices
            updatedAt = String(envelope.updated_at || state.updated_at || "")
            catalogError = devices.length === 0 ?
                "Geen volledig bekende Matter-apparaten gevonden" : ""
            catalogRevision++
        } catch (error) {
            knownDevices = [toonThermostatDevice()]
            catalogError = "ComfortHub is niet beschikbaar; Toon thermostaat blijft bruikbaar"
            catalogRevision++
        }
    }

    function refreshBridgeStatus() {
        try {
            var status = JSON.parse(bridgeStatusFile.read())
            bridgeRunning = status.running === true
            commissioned = status.commissioned === true
            pairingCode = String(status.pairing_code || "")
            pairingQrImage = String(status.qr_image || "")
            var energy = status.energy || ({})
            energyAvailable = energy.available === true
            energyOnline = energy.online === true
            energyImportW = Number(energy.import_power_w || 0)
            energyExportW = Number(energy.export_power_w || 0)
            energyNetW = Number(energy.net_power_w || 0)
            gasFlowLph = Number(energy.gas_flow_lph || 0)
            bridgeMessage = String(status.message || (commissioned ?
                "Gekoppeld met Google Home" : "Klaar om te koppelen"))
        } catch (error) {
            bridgeRunning = false
            commissioned = false
            pairingCode = ""
            pairingQrImage = ""
            energyAvailable = false
            energyOnline = false
            bridgeMessage = "Matter-service nog niet actief"
        }
    }

    function toonEnergyDevice() {
        var direction = energyNetW < 0 ? "teruglevering" : "afname"
        var watts = Math.abs(Math.round(energyNetW))
        var detail = "Elektriciteit · " + watts + " W " + direction
        if (gasFlowLph > 0)
            detail += " · gas " + Math.round(gasFlowLph) + " l/u"
        return {
            id: "toon-energy-meter",
            kind: "toon_energy",
            matter_type: "electrical_sensor",
            name: "Toon energiemeter",
            detail: detail + " · Matter-energiesensor",
            online: energyOnline
        }
    }

    function formattedPairingCode() {
        var code = String(pairingCode || "")
        if (code.length === 11)
            return code.substr(0, 4) + "-" + code.substr(4, 3) + "-" + code.substr(7, 4)
        return code
    }

    function climateDetail(device) {
        var brand = String(device.brand || device.provider || "Klimaat")
        var technology = String(device.technology || "")
        return brand + (technology.length > 0 ? " · " + technology : "") + " · Matter-thermostaat"
    }

    function deviceCount() {
        catalogRevision
        return knownDevices ? knownDevices.length : 0
    }

    function selected(deviceID) {
        selectionRevision
        return selections[String(deviceID)] === true
    }

    function setSelected(deviceID, enabled) {
        var id = String(deviceID || "")
        if (id.length === 0)
            return
        var updated = ({})
        for (var existing in selections)
            updated[existing] = selections[existing]
        updated[id] = enabled === true
        selections = updated
        preferencesFile.write(JSON.stringify({
            schema: "nl.toon.matter-bridge/preferences-v1",
            selected_devices: updated
        }, null, 2))
        selectionRevision++
    }

    function selectedCount() {
        catalogRevision
        selectionRevision
        var count = 0
        for (var i = 0; i < knownDevices.length; i++)
            if (selected(knownDevices[i].id)) count++
        return count
    }

    function selectionCountLabel() {
        var count = selectedCount()
        if (commissioned)
            return count + (count === 1 ? " apparaat gedeeld" : " apparaten gedeeld")
        return count + (count === 1 ? " apparaat geselecteerd" : " apparaten geselecteerd")
    }

    function connectionLabel() {
        if (commissioned) return "Gekoppeld"
        if (bridgeRunning) return "Klaar voor koppelen"
        return "Service ontbreekt"
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: matterBridgeApp.refresh()
    }

    FileIO {
        id: appBusStateFile
        source: "file:///var/volatile/tmp/toon-app-bus/v1/comfort-hub/state.json"
    }
    FileIO {
        id: preferencesFile
        source: "file:///mnt/data/tsc/matter-bridge.json"
    }
    FileIO {
        id: bridgeStatusFile
        source: "file:///var/volatile/tmp/toon-matter-bridge/status.json"
    }
    FileIO {
        id: tscCommandFile
        source: "file:///tmp/tsc.command"
    }
}
