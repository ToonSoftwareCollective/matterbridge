import { readFile, writeFile, rename, link, unlink, mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import {
  bridgedNode,
  electricalSensor,
  MatterbridgeDynamicPlatform,
  MatterbridgeEndpoint,
  powerSource,
  thermostat,
} from 'matterbridge';
import { ElectricalPowerMeasurement, Thermostat } from 'matterbridge/matter/clusters';

const STATE_PATH = '/var/volatile/tmp/toon-app-bus/v1/comfort-hub/state.json';
const PREFERENCES_PATH = '/mnt/data/tsc/matter-bridge.json';
const COMMAND_PATH = '/mnt/data/tsc/mhi-airco-control';
const STATUS_PATH = '/var/volatile/tmp/toon-matter-bridge/status.json';
const COMMISSIONED_FABRICS_PATH = '/mnt/data/tsc/matter-service/home/.matterbridge/matterstorage/Matterbridge/root.operationalCredentials.commissionedFabrics';
const TOON_THERMOSTAT_ID = 'toon-thermostat';
const TOON_THERMOSTAT_URL = 'http://127.0.0.1/happ_thermstat';
const TOON_ENERGY_ID = 'toon-energy-meter';
const TOON_ENERGY_URL = 'http://127.0.0.1/happ_pwrusage?action=GetCurrentUsage';
const POLL_MS = 5000;
// The service starts Matterbridge with this persistent setup payload. Platform
// plugins receive a restricted Matterbridge API that does not expose it.
const MANUAL_PAIRING_CODE = '31763538367';
const MATTER_QR_PAYLOAD = 'MT:Y.K904QI14BXPB0IC10';
const MATTER_QR_IMAGE = 'file:///qmf/qml/apps/matterbridge/drawables/MatterPairingQr.png';

const MODE_TO_MATTER = {
  off: Thermostat.SystemMode.Off,
  auto: Thermostat.SystemMode.Auto,
  cool: Thermostat.SystemMode.Cool,
  heat: Thermostat.SystemMode.Heat,
  fan_only: Thermostat.SystemMode.FanOnly,
  dry: Thermostat.SystemMode.Dry,
};

const MATTER_TO_MODE = new Map([
  [Thermostat.SystemMode.Off, 'off'],
  [Thermostat.SystemMode.Auto, 'auto'],
  [Thermostat.SystemMode.Cool, 'cool'],
  [Thermostat.SystemMode.Heat, 'heat'],
  [Thermostat.SystemMode.FanOnly, 'fan_only'],
  [Thermostat.SystemMode.Dry, 'dry'],
]);

async function readJson(path, fallback) {
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch {
    return fallback;
  }
}

async function atomicJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  const temp = `${path}.tmp-${process.pid}`;
  await writeFile(temp, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  await rename(temp, path);
}

async function enqueueCommand(command) {
  const temp = `${COMMAND_PATH}.matter-${process.pid}-${Date.now()}`;
  await writeFile(temp, `${JSON.stringify(command)}\n`, 'utf8');
  try {
    await link(temp, COMMAND_PATH);
  } finally {
    await unlink(temp).catch(() => {});
  }
}

async function readToonThermostat() {
  const response = await fetch(`${TOON_THERMOSTAT_URL}?action=getThermostatInfo`, {
    signal: AbortSignal.timeout(2500),
  });
  if (!response.ok) throw new Error(`Toon-thermostaat gaf HTTP ${response.status}`);
  const data = await response.json();
  const current = Number(data.currentTemp) / 100;
  const target = Number(data.currentSetpoint) / 100;
  if (data.result !== 'ok' || !Number.isFinite(current) || !Number.isFinite(target)) {
    throw new Error('Toon-thermostaat gaf geen geldige temperatuur terug');
  }
  return {
    id: TOON_THERMOSTAT_ID,
    source: 'toon',
    matter_eligible: true,
    matter_type: 'thermostat',
    name: 'Toon thermostaat',
    current_temperature: current,
    target_temperature: target,
    min_temperature: 6,
    max_temperature: 30,
    mode: 'heat',
    online: true,
  };
}

async function readToonEnergy() {
  const response = await fetch(TOON_ENERGY_URL, { signal: AbortSignal.timeout(2500) });
  if (!response.ok) throw new Error(`Toon-energiemeter gaf HTTP ${response.status}`);
  const data = await response.json();
  const importPower = Number(data?.powerUsage?.value);
  const exportPower = Number(data?.powerProduction?.value);
  const gasFlow = Number(data?.gasUsage?.value);
  if (data.result !== 'ok' || !Number.isFinite(importPower) || !Number.isFinite(exportPower)) {
    throw new Error('Toon-energiemeter gaf geen geldige vermogens terug');
  }
  return {
    id: TOON_ENERGY_ID,
    source: 'toon',
    matter_eligible: true,
    matter_type: 'electrical_sensor',
    name: 'Toon energiemeter',
    import_power_w: importPower,
    export_power_w: exportPower,
    net_power_w: importPower - exportPower,
    gas_flow_lph: Number.isFinite(gasFlow) ? gasFlow : null,
    online: true,
  };
}

export default function initializePlugin(matterbridge, log, config) {
  return new ToonMatterPlatform(matterbridge, log, config);
}

export class ToonMatterPlatform extends MatterbridgeDynamicPlatform {
  constructor(matterbridge, log, config) {
    super(matterbridge, log, config);
    this.devices = new Map();
    this.pollTimer = undefined;
    this.reconciling = false;
    this.lastStatusSignature = '';
    this.lastToonState = undefined;
    this.toonReadFailed = false;
    this.lastEnergyState = undefined;
    this.energyReadFailed = false;
    this.log.info('Toon Matter-platform geïnitialiseerd');
  }

  async onStart(reason) {
    this.log.info('Toon Matter-platform start:', reason ?? 'startup');
    await this.ready;
    await this.reconcile();
    this.pollTimer = setInterval(() => void this.reconcile(), POLL_MS);
  }

  async onShutdown(reason) {
    if (this.pollTimer) clearInterval(this.pollTimer);
    await this.writeStatus(false, `Matter-service gestopt: ${reason ?? 'shutdown'}`);
    await super.onShutdown(reason);
  }

  async reconcile() {
    if (this.reconciling) return;
    this.reconciling = true;
    try {
      const envelope = await readJson(STATE_PATH, null);
      const preferences = await readJson(PREFERENCES_PATH, { selected_devices: {} });
      const selected = preferences?.selected_devices ?? {};
      const state = envelope?.state ?? envelope;
      const catalog = Array.isArray(state?.devices) ? [...state.devices] : [];
      try {
        this.lastToonState = await readToonThermostat();
        if (this.toonReadFailed) this.log.notice('Toon-thermostaat is weer bereikbaar');
        this.toonReadFailed = false;
      } catch (error) {
        if (!this.toonReadFailed) {
          this.log.warn('Toon-thermostaat uitlezen mislukt:', error?.message ?? String(error));
        }
        this.toonReadFailed = true;
      }
      catalog.push(this.lastToonState ?? {
        id: TOON_THERMOSTAT_ID,
        source: 'toon',
        matter_eligible: true,
        matter_type: 'thermostat',
        name: 'Toon thermostaat',
        current_temperature: 20,
        target_temperature: 20,
        min_temperature: 6,
        max_temperature: 30,
        mode: 'heat',
        online: false,
      });
      try {
        this.lastEnergyState = await readToonEnergy();
        if (this.energyReadFailed) this.log.notice('Toon-energiemeter is weer bereikbaar');
        this.energyReadFailed = false;
      } catch (error) {
        if (!this.energyReadFailed) {
          this.log.warn('Toon-energiemeter uitlezen mislukt:', error?.message ?? String(error));
        }
        this.energyReadFailed = true;
        if (this.lastEnergyState) this.lastEnergyState = { ...this.lastEnergyState, online: false };
      }
      if (this.lastEnergyState) catalog.push(this.lastEnergyState);

      const eligible = catalog.filter((device) => device?.matter_eligible === true
        && ['thermostat', 'electrical_sensor'].includes(device?.matter_type)
        && device?.id);
      const wanted = new Set(eligible.filter((device) => selected[String(device.id)] === true).map((device) => String(device.id)));

      for (const [id, entry] of this.devices) {
        if (!wanted.has(id)) {
          await this.unregisterDevice(entry.endpoint);
          this.devices.delete(id);
          this.log.notice(`Niet meer via Matter gedeeld: ${entry.name}`);
        }
      }

      const climateDevices = eligible.filter((device) => device.matter_type === 'thermostat');
      for (let index = 0; index < climateDevices.length; index += 1) {
        const device = climateDevices[index];
        const id = String(device.id);
        if (!wanted.has(id)) continue;
        let entry = this.devices.get(id);
        if (!entry) {
          entry = await this.addClimateDevice(device, index + 1);
          this.devices.set(id, entry);
        }
        entry.slot = index + 1;
        entry.name = String(device.name);
        entry.source = String(device.source || 'comfort-hub');
        await this.updateClimateDevice(entry, device);
      }

      const energyDevice = eligible.find((device) => device.matter_type === 'electrical_sensor');
      if (energyDevice && wanted.has(String(energyDevice.id))) {
        const id = String(energyDevice.id);
        let entry = this.devices.get(id);
        if (!entry) {
          entry = await this.addEnergyDevice(energyDevice);
          this.devices.set(id, entry);
        }
        await this.updateEnergyDevice(entry, energyDevice);
      }

      const count = this.devices.size;
      await this.writeStatus(true, count === 0
        ? 'Matter-service actief; kies minimaal één apparaat'
        : `${count} ${count === 1 ? 'apparaat' : 'apparaten'} via Matter gedeeld`);
    } catch (error) {
      this.log.error('Matter-synchronisatie mislukt:', error?.message ?? String(error));
      await this.writeStatus(true, `Synchronisatie mislukt: ${error?.message ?? String(error)}`);
    } finally {
      this.reconciling = false;
    }
  }

  async addClimateDevice(device, slot) {
    const current = Number.isFinite(device.current_temperature) ? Number(device.current_temperature) : 20;
    const target = Number.isFinite(device.target_temperature) ? Number(device.target_temperature) : 21;
    const minimum = Number.isFinite(device.min_temperature) ? Number(device.min_temperature) : 16;
    const maximum = Number.isFinite(device.max_temperature) ? Number(device.max_temperature) : 30;
    const name = String(device.name).slice(0, 32);
    const serial = `TOON-${String(device.id).replace(/[^A-Za-z0-9]/g, '').slice(-20).toUpperCase()}`;
    const endpoint = new MatterbridgeEndpoint([thermostat, bridgedNode, powerSource], { id: String(device.id) }, this.config.debug)
      .createDefaultIdentifyClusterServer()
      .createDefaultBridgedDeviceBasicInformationClusterServer(name, serial, 0xfff1, 'Toon', 'Toon klimaatapparaat')
      .createDefaultThermostatClusterServer(current, target, target, 1, minimum, maximum - 1, minimum + 1, maximum)
      .createDefaultPowerSourceWiredClusterServer()
      .addRequiredClusterServers();

    const entry = { endpoint, slot, name, source: String(device.source || 'comfort-hub'), last: {} };
    endpoint.subscribeAttribute(Thermostat, 'systemMode', (value, _oldValue, context) => {
      if (context?.fabric === undefined) return;
      if (entry.source === 'toon') return;
      const mode = MATTER_TO_MODE.get(value);
      if (!mode) return;
      void this.sendClimateCommand(entry, 'mode', mode);
    }, endpoint.log);
    endpoint.subscribeAttribute(Thermostat, 'occupiedHeatingSetpoint', (value, _oldValue, context) => {
      if (context?.fabric === undefined) return;
      void this.sendClimateCommand(entry, 'temperature', value / 100);
    }, endpoint.log);
    endpoint.subscribeAttribute(Thermostat, 'occupiedCoolingSetpoint', (value, _oldValue, context) => {
      if (context?.fabric === undefined) return;
      void this.sendClimateCommand(entry, 'temperature', value / 100);
    }, endpoint.log);

    await this.registerDevice(endpoint);
    this.log.notice(`Via Matter gedeeld: ${name}`);
    return entry;
  }

  async updateClimateDevice(entry, device) {
    const endpoint = entry.endpoint;
    const current = Number(device.current_temperature);
    const target = Number(device.target_temperature);
    const mode = MODE_TO_MATTER[String(device.mode)] ?? Thermostat.SystemMode.Off;
    const currentValue = Math.round(current * 100);
    if (Number.isFinite(current) && entry.last.current !== currentValue) {
      await endpoint.setAttribute(Thermostat.id, 'localTemperature', currentValue, endpoint.log);
      entry.last.current = currentValue;
    }
    const targetValue = Math.round(target * 100);
    if (Number.isFinite(target) && entry.last.target !== targetValue) {
      const setpoint = Math.round(target * 100);
      await endpoint.setAttribute(Thermostat.id, 'occupiedHeatingSetpoint', setpoint, endpoint.log);
      await endpoint.setAttribute(Thermostat.id, 'occupiedCoolingSetpoint', setpoint, endpoint.log);
      entry.last.target = targetValue;
    }
    if (entry.last.mode !== mode) {
      await endpoint.setAttribute(Thermostat.id, 'systemMode', mode, endpoint.log);
      entry.last.mode = mode;
    }
  }

  async addEnergyDevice(device) {
    const name = String(device.name).slice(0, 32);
    const serial = 'TOON-ENERGY-METER';
    // Matter represents ActivePower in milliwatts. A negative value means
    // power is being exported to the grid.
    const activePower = Math.round(Number(device.net_power_w) * 1000);
    const endpoint = new MatterbridgeEndpoint(
      [electricalSensor, bridgedNode, powerSource],
      { id: String(device.id) },
      this.config.debug,
    )
      .createDefaultIdentifyClusterServer()
      .createDefaultBridgedDeviceBasicInformationClusterServer(name, serial, 0xfff1, 'Toon', 'Toon energiemeter')
      .createDefaultPowerSourceWiredClusterServer()
      .createDefaultPowerTopologyClusterServer()
      .createDefaultElectricalPowerMeasurementClusterServer(null, null, activePower, 50000)
      .addRequiredClusterServers();

    const entry = { endpoint, name, source: 'toon', last: {} };
    await this.registerDevice(endpoint);
    this.log.notice(`Via Matter gedeeld: ${name}`);
    return entry;
  }

  async updateEnergyDevice(entry, device) {
    const activePower = Math.round(Number(device.net_power_w) * 1000);
    if (Number.isFinite(activePower) && entry.last.activePower !== activePower) {
      await entry.endpoint.setAttribute(
        ElectricalPowerMeasurement.id,
        'activePower',
        activePower,
        entry.endpoint.log,
      );
      entry.last.activePower = activePower;
    }
  }

  async sendClimateCommand(entry, command, value) {
    try {
      if (entry.source === 'toon') {
        if (command !== 'temperature') return;
        const temperature = Math.max(6, Math.min(30, Number(value)));
        if (!Number.isFinite(temperature)) throw new Error('ongeldige doeltemperatuur');
        const response = await fetch(
          `${TOON_THERMOSTAT_URL}?action=setSetpoint&Setpoint=${Math.round(temperature * 10)}`,
          { signal: AbortSignal.timeout(2500) },
        );
        if (!response.ok) throw new Error(`Toon-thermostaat gaf HTTP ${response.status}`);
        const result = await response.json();
        if (result.result !== 'ok') throw new Error('Toon-thermostaat weigerde het setpoint');
        this.log.info(`Google Home → ${entry.name}: temperatuur=${temperature}`);
        return;
      }
      await enqueueCommand({ type: 'climate', slot: entry.slot, command, value });
      this.log.info(`Google Home → ${entry.name}: ${command}=${value}`);
    } catch (error) {
      this.log.error(`Commando voor ${entry.name} mislukt:`, error?.message ?? String(error));
    }
  }

  async writeStatus(running, message) {
    const serverNode = this.matterbridge?.serverNode;
    const commissioning = serverNode?.state?.commissioning;
    let matterData = {};
    try {
      if (serverNode && typeof this.matterbridge?.getServerNodeData === 'function') {
        matterData = this.matterbridge.getServerNodeData(serverNode) ?? {};
      }
    } catch {
      matterData = {};
    }
    const storedFabricCount = Number(await readFile(COMMISSIONED_FABRICS_PATH, 'utf8').catch(() => '0'));
    const commissioned = matterData.commissioned === true
      || commissioning?.commissioned === true
      || serverNode?.lifecycle?.isCommissioned === true
      || storedFabricCount > 0;
    const status = {
      schema: 'nl.toon.matter-bridge/status-v1',
      running,
      commissioned,
      message: commissioned ? `${message}; gekoppeld met Google Home` : message,
      pairing_code: commissioned ? '' : String(
        matterData.manualPairingCode ?? commissioning?.pairingCodes?.manualPairingCode ?? MANUAL_PAIRING_CODE,
      ),
      qr_payload: commissioned ? '' : MATTER_QR_PAYLOAD,
      qr_image: commissioned ? '' : MATTER_QR_IMAGE,
      selected_count: this.devices.size,
      energy: this.lastEnergyState ? {
        available: true,
        online: this.lastEnergyState.online === true,
        import_power_w: this.lastEnergyState.import_power_w,
        export_power_w: this.lastEnergyState.export_power_w,
        net_power_w: this.lastEnergyState.net_power_w,
        gas_flow_lph: this.lastEnergyState.gas_flow_lph,
      } : { available: false, online: false },
    };
    const signature = JSON.stringify(status);
    if (signature === this.lastStatusSignature) return;
    await atomicJson(STATUS_PATH, {
      ...status,
      updated_at: new Date().toISOString(),
    });
    this.lastStatusSignature = signature;
  }
}
