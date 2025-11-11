import 'package:flutter/material.dart';

// Plant Phase Enum
enum PlantPhase {
  seedling,
  veg,
  bloom,
  harvest,
  archived;

  String get prefix {
    switch (this) {
      case PlantPhase.seedling:
        return 'S';
      case PlantPhase.veg:
        return 'V';
      case PlantPhase.bloom:
        return 'B';
      case PlantPhase.harvest:
        return 'H';
      case PlantPhase.archived:
        return 'A';
    }
  }

  String get displayName {
    switch (this) {
      case PlantPhase.seedling:
        return 'Seedling';
      case PlantPhase.veg:
        return 'Vegetative Phase';
      case PlantPhase.bloom:
        return 'Bloom Phase';
      case PlantPhase.harvest:
        return 'Harvest';
      case PlantPhase.archived:
        return 'Archived';
    }
  }
}

// ✅ KORRIGIERT: Seed Type Enum (nur photo und auto)
enum SeedType {
  photo,
  auto;

  String get displayName {
    switch (this) {
      case SeedType.photo:
        return 'Photoperiod';
      case SeedType.auto:
        return 'Autoflower';
    }
  }
}

// ✅ NEU: Gender Type Enum für Feminized/Regular
enum GenderType {
  feminized,
  regular;

  String get displayName {
    switch (this) {
      case GenderType.feminized:
        return 'Feminized';
      case GenderType.regular:
        return 'Regular';
    }
  }
}

// Hardware Category Enum
enum HardwareCategory {
  lighting,
  climate,
  watering,
  monitoring,
  other;

  String get displayName {
    switch (this) {
      case HardwareCategory.lighting:
        return 'Lighting';
      case HardwareCategory.climate:
        return 'Climate';
      case HardwareCategory.watering:
        return 'Watering';
      case HardwareCategory.monitoring:
        return 'Monitoring';
      case HardwareCategory.other:
        return 'Other';
    }
  }
}

// Hardware Type Enum
enum HardwareType {
  // Lighting
  light,
  ledPanel,
  hpsLamp,
  mhLamp,
  cflLamp,

  // Climate
  fan,
  exhaustFan,
  circulationFan,
  humidifier,
  dehumidifier,
  heater,
  ac,
  airConditioner,

  // Control
  controller,
  timer,

  // Sensors
  sensor,
  phMeter,
  ecMeter,
  thermometer,
  hygrometer,
  co2Sensor,

  // Watering
  irrigation,
  pump,
  dripSystem,
  reservoir,
  filter,

  // Other
  other;

  HardwareCategory get category {
    switch (this) {
      case HardwareType.light:
      case HardwareType.ledPanel:
      case HardwareType.hpsLamp:
      case HardwareType.mhLamp:
      case HardwareType.cflLamp:
        return HardwareCategory.lighting;

      case HardwareType.fan:
      case HardwareType.exhaustFan:
      case HardwareType.circulationFan:
      case HardwareType.humidifier:
      case HardwareType.dehumidifier:
      case HardwareType.heater:
      case HardwareType.ac:
      case HardwareType.airConditioner:
        return HardwareCategory.climate;

      case HardwareType.irrigation:
      case HardwareType.pump:
      case HardwareType.dripSystem:
      case HardwareType.reservoir:
      case HardwareType.filter:
        return HardwareCategory.watering;

      case HardwareType.sensor:
      case HardwareType.phMeter:
      case HardwareType.ecMeter:
      case HardwareType.thermometer:
      case HardwareType.hygrometer:
      case HardwareType.co2Sensor:
        return HardwareCategory.monitoring;

      case HardwareType.controller:
      case HardwareType.timer:
      case HardwareType.other:
        return HardwareCategory.other;
    }
  }

  IconData get icon {
    switch (this) {
      case HardwareType.light:
      case HardwareType.ledPanel:
      case HardwareType.hpsLamp:
      case HardwareType.mhLamp:
      case HardwareType.cflLamp:
        return Icons.lightbulb;

      case HardwareType.fan:
      case HardwareType.exhaustFan:
      case HardwareType.circulationFan:
        return Icons.air;

      case HardwareType.humidifier:
        return Icons.water_drop;

      case HardwareType.dehumidifier:
        return Icons.water_drop_outlined;

      case HardwareType.heater:
        return Icons.whatshot;

      case HardwareType.ac:
      case HardwareType.airConditioner:
        return Icons.ac_unit;

      case HardwareType.controller:
        return Icons.settings_remote;

      case HardwareType.sensor:
      case HardwareType.phMeter:
      case HardwareType.ecMeter:
      case HardwareType.thermometer:
      case HardwareType.hygrometer:
      case HardwareType.co2Sensor:
        return Icons.sensors;

      case HardwareType.irrigation:
      case HardwareType.pump:
      case HardwareType.dripSystem:
      case HardwareType.reservoir:
        return Icons.opacity;

      case HardwareType.filter:
        return Icons.filter_alt;

      case HardwareType.timer:
        return Icons.timer;

      case HardwareType.other:
        return Icons.device_unknown;
    }
  }

  String get displayName {
    switch (this) {
      case HardwareType.light:
        return 'Light';
      case HardwareType.ledPanel:
        return 'LED Panel';
      case HardwareType.hpsLamp:
        return 'HPS Lamp';
      case HardwareType.mhLamp:
        return 'MH Lamp';
      case HardwareType.cflLamp:
        return 'CFL Lamp';
      case HardwareType.fan:
        return 'Fan';
      case HardwareType.exhaustFan:
        return 'Exhaust Fan';
      case HardwareType.circulationFan:
        return 'Circulation Fan';
      case HardwareType.humidifier:
        return 'Humidifier';
      case HardwareType.dehumidifier:
        return 'Dehumidifier';
      case HardwareType.heater:
        return 'Heater';
      case HardwareType.ac:
      case HardwareType.airConditioner:
        return 'Air Conditioner';
      case HardwareType.controller:
        return 'Controller';
      case HardwareType.sensor:
        return 'Sensor';
      case HardwareType.phMeter:
        return 'pH Meter';
      case HardwareType.ecMeter:
        return 'EC Meter';
      case HardwareType.thermometer:
        return 'Thermometer';
      case HardwareType.hygrometer:
        return 'Hygrometer';
      case HardwareType.co2Sensor:
        return 'CO2 Sensor';
      case HardwareType.irrigation:
        return 'Irrigation';
      case HardwareType.pump:
        return 'Pump';
      case HardwareType.dripSystem:
        return 'Drip System';
      case HardwareType.reservoir:
        return 'Reservoir';
      case HardwareType.filter:
        return 'Filter';
      case HardwareType.timer:
        return 'Timer';
      case HardwareType.other:
        return 'Other';
    }
  }
}

// Action Type Enum
enum ActionType {
  water,
  feed,
  trim,
  transplant,
  training,
  note,
  phaseChange,
  harvest,
  other;

  String get displayName {
    switch (this) {
      case ActionType.water:
        return 'Watering';
      case ActionType.feed:
        return 'Feeding';
      case ActionType.trim:
        return 'Trimming';
      case ActionType.transplant:
        return 'Transplanting';
      case ActionType.training:
        return 'Training';
      case ActionType.note:
        return 'Note';
      case ActionType.phaseChange:
        return 'Phase Change';
      case ActionType.harvest:
        return 'Harvest';
      case ActionType.other:
        return 'Other';
    }
  }
}

// Medium Enum (Original 6 Werte)
enum Medium {
  erde,
  coco,
  hydro,
  aero,
  dwc,
  rdwc;

  bool get needsRunoffMeasurement {
    switch (this) {
      case Medium.erde:
      case Medium.coco:
        return true;
      case Medium.hydro:
      case Medium.aero:
      case Medium.dwc:
      case Medium.rdwc:
        return false;
    }
  }

  bool get needsRunoffFlags {
    switch (this) {
      case Medium.erde:
      case Medium.coco:
        return true;
      case Medium.hydro:
      case Medium.aero:
      case Medium.dwc:
      case Medium.rdwc:
        return false;
    }
  }

  String get displayName {
    switch (this) {
      case Medium.erde:
        return 'Soil/Erde';
      case Medium.coco:
        return 'Coco';
      case Medium.hydro:
        return 'Hydro';
      case Medium.aero:
        return 'Aero';
      case Medium.dwc:
        return 'DWC';
      case Medium.rdwc:
        return 'RDWC';
    }
  }
}

// Grow Type Enum
enum GrowType {
  indoor,
  outdoor,
  greenhouse;

  String get displayName {
    switch (this) {
      case GrowType.indoor:
        return 'Indoor';
      case GrowType.outdoor:
        return 'Outdoor';
      case GrowType.greenhouse:
        return 'Greenhouse';
    }
  }
}

// ✅ BUG FIX #1: Watering System mit DB-kompatiblen Werten
enum WateringSystem {
  manual, // statt "hand" - passt zu DB 'MANUAL'
  drip,
  autopot,
  rdwc,
  floodDrain; // statt "ebbFlow" - passt zu DB 'FLOOD_DRAIN'

  String get displayName {
    switch (this) {
      case WateringSystem.manual:
        return 'Hand/Manual';
      case WateringSystem.drip:
        return 'Drip Irrigation';
      case WateringSystem.autopot:
        return 'Autopot';
      case WateringSystem.rdwc:
        return 'RDWC (Recirculating DWC)';
      case WateringSystem.floodDrain:
        return 'Ebb & Flow (Flood & Drain)';
    }
  }
}
