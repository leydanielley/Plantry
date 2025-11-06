# RDWC System Management - Expert Mode Feature

## Overview
The RDWC (Recirculating Deep Water Culture) System Management feature is an **Expert Mode-only** advanced tool for tracking hydroponic reservoir systems. It allows precise monitoring of water consumption, addback events, and system health for RDWC setups.

## What Was Implemented

### ✅ Backend Complete (Database v2 → v3)

#### 1. **Models Created**
- `RdwcSystem` (`lib/models/rdwc_system.dart`)
  - Tracks RDWC system with max capacity and current level
  - Linked to rooms and grows
  - Calculates fill percentage, remaining capacity
  - Status indicators: low water, critical, full

- `RdwcLog` (`lib/models/rdwc_log.dart`)
  - Tracks water addback events
  - Log types: Addback, Full Change, Maintenance, Measurement
  - Records water consumed, added, level before/after
  - Tracks pH/EC before/after for drift analysis

#### 2. **Database Tables** (v3 Migration)
- `rdwc_systems` - Stores system configurations
- `rdwc_logs` - Stores addback and maintenance logs
- Automatic migration from v2 → v3 for existing users
- Proper indexes for performance

#### 3. **Repository** (`lib/repositories/rdwc_repository.dart`)
- Full CRUD operations for systems and logs
- Query methods:
  - Get systems by room/grow
  - Get recent logs
  - Calculate average daily consumption
  - Calculate total water added in time period
- Auto-updates system level when logging addbacks

#### 4. **Translations**
- Full German and English translations
- 34 new translation keys added
- Covers all UI elements and messages

#### 5. **Unit Conversion Support**
- Integrates with new measurement units feature
- Display in Liters or Gallons based on user preference
- EC or PPM for nutrient readings

## How It Works

### System Concept
An RDWC System represents:
- **Reservoir**: The main water tank
- **Max Capacity**: Total system capacity (buckets + reservoir)
- **Current Level**: How much water is in the system now
- **Linked Plants**: Plants using this system (future feature)

### Addback Logging Workflow
1. **Before Addback**: Measure current water level
2. **Calculate Consumption**: System calculates how much water plants consumed
3. **Add Water**: Log how much water you added back
4. **After Addback**: New water level
5. **Track Metrics**: pH/EC before and after to see drift

### Example Use Case
```
Day 1: Fill new RDWC system
  - Max Capacity: 100 L
  - Current Level: 100 L
  - EC: 1.8, pH: 5.8

Day 3: First Addback
  - Level Before: 85 L (consumed: 15 L in 2 days)
  - Water Added: 15 L
  - Level After: 100 L
  - EC Before: 2.1 (drift +0.3)
  - EC After: 1.8 (adjusted back)
  - pH Before: 6.2 (drift +0.4)
  - pH After: 5.8 (adjusted back)

Day 5: Second Addback
  - Level Before: 78 L (consumed: 22 L in 2 days)
  - Average consumption: 11 L/day
  - System calculates trends and alerts you
```

## Data Tracked

### Per System
- Name and description
- Room and grow assignment
- Max reservoir capacity
- Current water level
- Creation date
- Archive status

### Per Log Entry
- Log date and time
- Log type (addback, full change, maintenance, measurement)
- Water level before
- Water amount added
- Water level after
- Water consumed (calculated)
- pH before/after
- EC before/after
- Notes
- Who logged it

## Calculated Metrics

The system automatically calculates:
- **Fill Percentage**: `(currentLevel / maxCapacity) × 100`
- **Remaining Capacity**: `maxCapacity - currentLevel`
- **Water Consumed**: `levelAfter (previous log) - levelBefore (current log)`
- **EC Drift**: `ecAfter - ecBefore` (positive = EC rising)
- **pH Drift**: `phAfter - phBefore` (positive = pH rising)
- **Average Daily Consumption**: Based on last 7 days of logs
- **Total Water Added**: Sum over any time period

## Status Indicators

The system provides automatic warnings:
- **Normal**: 30-100% full (green)
- **Low Water**: Below 30% (yellow warning)
- **Critical**: Below 15% (red alert)
- **Full**: Above 95% (blue)

## Database Schema

### rdwc_systems Table
```sql
CREATE TABLE rdwc_systems (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  room_id INTEGER,                -- Optional link to room
  grow_id INTEGER,                -- Optional link to grow
  max_capacity REAL NOT NULL,     -- In liters
  current_level REAL DEFAULT 0,   -- In liters
  description TEXT,
  created_at TEXT,
  archived INTEGER DEFAULT 0,
  FOREIGN KEY (room_id) REFERENCES rooms(id),
  FOREIGN KEY (grow_id) REFERENCES grows(id)
);
```

### rdwc_logs Table
```sql
CREATE TABLE rdwc_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  system_id INTEGER NOT NULL,
  log_date TEXT,
  log_type TEXT CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
  level_before REAL,              -- Level before action
  water_added REAL,               -- Amount added
  level_after REAL,               -- Level after action
  water_consumed REAL,            -- Calculated consumption
  ph_before REAL,
  ph_after REAL,
  ec_before REAL,
  ec_after REAL,
  note TEXT,
  logged_by TEXT,
  created_at TEXT,
  FOREIGN KEY (system_id) REFERENCES rdwc_systems(id) ON DELETE CASCADE
);
```

## Repository Methods

### Systems
- `getAllSystems({includeArchived})` - Get all systems
- `getSystemsByRoom(roomId)` - Get systems in a room
- `getSystemsByGrow(growId)` - Get systems for a grow
- `getSystemById(id)` - Get single system
- `createSystem(system)` - Create new system
- `updateSystem(system)` - Update system
- `updateSystemLevel(systemId, newLevel)` - Update just the level
- `archiveSystem(systemId, archived)` - Archive/unarchive
- `deleteSystem(systemId)` - Delete system and all logs

### Logs
- `getLogsBySystem(systemId)` - Get all logs for a system
- `getRecentLogs(systemId, {limit})` - Get last N logs
- `getLatestLog(systemId)` - Get most recent log
- `createLog(log)` - Create log and update system level
- `updateLog(log)` - Update log
- `deleteLog(logId)` - Delete log
- `getAverageDailyConsumption(systemId, {days})` - Calculate avg consumption
- `getTotalWaterAdded(systemId, {startDate, endDate})` - Total water added

## UI Screens (To Be Implemented)

### 1. RDWC Systems List Screen
- **Access**: Main menu (Expert Mode only)
- **Features**:
  - List all RDWC systems
  - Show current level, fill %, status
  - Quick add system button
  - Filter by room/grow
  - Archive management

### 2. System Detail/Monitoring Screen
- **Access**: Tap on a system from list
- **Features**:
  - System overview card (capacity, level, %)
  - Status indicator with color coding
  - Recent logs timeline
  - Quick addback button
  - Statistics: avg consumption, total added
  - Charts: consumption over time, EC/pH drift

### 3. Create/Edit System Form
- **Fields**:
  - System name*
  - Description
  - Room (optional dropdown)
  - Grow (optional dropdown)
  - Max capacity* (with unit conversion)

### 4. Addback Logging Form
- **Quick Mode**:
  - Level before (pre-filled from system)
  - Water added*
  - Level after (auto-calculated or manual)
  - Note (optional)

- **Expert Mode**:
  - All quick mode fields
  - pH before/after
  - EC before/after
  - Log type selection
  - Logged by name

## Integration with Existing Features

### Expert Mode
- RDWC menu item only visible when Expert Mode enabled
- Settings toggle: `GrowLogApp.of(context)?.settings.isExpertMode`

### Measurement Units
- All water volumes respect user's volume unit preference (L/gal)
- EC values respect EC/PPM preference
- Auto-conversion on display using `UnitConverter` utility

### Rooms
- Systems can be assigned to rooms
- Filter systems by room

### Grows
- Systems can be assigned to grows
- Track system history per grow cycle

### Plants (Future)
- Link plants to RDWC systems
- Calculate per-plant consumption
- Track which plants are in which buckets

## Next Steps (UI Implementation)

To complete this feature, implement these screens:

1. **Create RdwcSystemsScreen** (`lib/screens/rdwc_systems_screen.dart`)
   - List view of all systems
   - Add new system FAB
   - Show status indicators

2. **Create RdwcSystemDetailScreen** (`lib/screens/rdwc_system_detail_screen.dart`)
   - System overview
   - Logs timeline
   - Statistics
   - Quick addback button

3. **Create RdwcSystemFormScreen** (`lib/screens/rdwc_system_form_screen.dart`)
   - Create/edit system form
   - Validation
   - Unit conversion helpers

4. **Create RdwcAddbackFormScreen** (`lib/screens/rdwc_addback_form_screen.dart`)
   - Addback logging form
   - Auto-calculate consumed water
   - pH/EC tracking
   - Log type selection

5. **Add Navigation**
   - Add "RDWC Systems" to main menu (expert mode only)
   - Check: `if (settings.isExpertMode) { ... }`

## Code Example: Using the Repository

```dart
import '../repositories/rdwc_repository.dart';
import '../models/rdwc_system.dart';
import '../models/rdwc_log.dart';

final repo = RdwcRepository();

// Create a new RDWC system
final system = RdwcSystem(
  name: 'Main Grow Tent RDWC',
  roomId: 1,
  growId: 5,
  maxCapacity: 100.0,  // 100 liters
  currentLevel: 100.0,
  description: '4 bucket RDWC with 40L reservoir',
);
final systemId = await repo.createSystem(system);

// Log an addback
final log = RdwcLog(
  systemId: systemId,
  logType: RdwcLogType.addback,
  levelBefore: 85.0,
  waterAdded: 15.0,
  levelAfter: 100.0,
  waterConsumed: 15.0,  // Previous level (100) - levelBefore (85)
  ecBefore: 2.1,
  ecAfter: 1.8,
  phBefore: 6.2,
  phAfter: 5.8,
  note: 'Plants drinking heavily in week 3 of bloom',
);
await repo.createLog(log);

// Get average daily consumption
final avgConsumption = await repo.getAverageDailyConsumption(systemId, days: 7);
print('Average: ${avgConsumption}L per day');

// Get system status
final currentSystem = await repo.getSystemById(systemId);
if (currentSystem != null) {
  print('Fill: ${currentSystem.fillPercentage}%');
  print('Low water: ${currentSystem.isLowWater}');
  print('Remaining: ${currentSystem.remainingCapacity}L');
}
```

## Benefits

### For Users
- **Precision Tracking**: Know exactly how much water plants are drinking
- **Trend Analysis**: See consumption patterns over time
- **Early Warning**: Get alerts when reservoir is low
- **pH/EC Management**: Track nutrient and pH drift between changes
- **Historical Data**: Review past performance for future grows

### For Growers
- **Optimize Feeding**: Understand nutrient uptake rates
- **Prevent Issues**: Catch problems early (over-drinking, under-drinking)
- **Plan Addbacks**: Predict when you'll need to add water
- **Compare Grows**: See how different strains consume water
- **Professional Records**: Detailed logs for serious growers

## Future Enhancements

- **Plant Assignment**: Link specific plants to systems
- **Bucket Tracking**: Track individual bucket levels
- **Automated Alerts**: Notifications when level is low
- **Charts/Graphs**: Visual consumption trends
- **Export Reports**: PDF reports for grow cycles
- **Nutrient Calculator**: Suggest addback amounts based on EC drift
- **Temperature Tracking**: Log reservoir temperature
- **Chiller Control**: Track chiller on/off times
- **Multi-System**: Compare multiple systems side-by-side
