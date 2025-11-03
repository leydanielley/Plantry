// =============================================
// GROWLOG - Translations / i18n
// =============================================

class AppTranslations {
  final String languageCode;

  AppTranslations(this.languageCode);

  static final Map<String, Map<String, String>> _translations = {
    // GERMAN
    'de': {
      // Navigation
      'app_name': 'GrowLog',
      'dashboard': 'Dashboard',
      'plants': 'Pflanzen',
      'grows': 'Grows',
      'rooms': 'Räume',
      'fertilizers': 'Dünger',
      'hardware': 'Hardware',
      'harvests': 'Ernten',
      'settings': 'Einstellungen',
      
      // Dashboard
      'welcome': 'Willkommen',
      'overview': 'Übersicht',
      'statistics': 'Statistiken',
      'active_grows': 'Aktive Grows',
      'total_plants': 'Pflanzen gesamt',
      'active_plants': 'Aktive Pflanzen',
      'plants_by_phase': 'Pflanzen nach Phase',
      'quick_actions': 'Schnellzugriff',
      'recent_activity': 'Letzte Aktivitäten',
      
      // Statistics
      'total': 'Gesamt',
      'active': 'Aktiv',
      'archived': 'Archiviert',
      
      // Phases
      'seedling': 'Keimling',
      'veg': 'Wachstum',
      'bloom': 'Blüte',
      'harvest': 'Ernte',
      'phase_archived': 'Archiviert',
      
      // Actions
      'add_plant': 'Pflanze hinzufügen',
      'add_grow': 'Grow hinzufügen',
      'add_log': 'Log hinzufügen',
      'add_room': 'Raum hinzufügen',
      'add_fertilizer': 'Dünger hinzufügen',
      'add_hardware': 'Hardware hinzufügen',
      'new_plant': 'Neue Pflanze',
      'delete': 'Löschen',
      'edit': 'Bearbeiten',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      
      // Settings
      'language': 'Sprache',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'dark_mode_enabled': 'Dark Mode aktiviert 🌙',
      'light_mode_enabled': 'Light Mode aktiviert ☀️',
      'german': 'Deutsch',
      'english': 'English',

      // Backup & Restore
      'backup_restore': 'Backup & Wiederherstellung',
      'export_data': 'Daten exportieren',
      'export_data_desc': 'Alle Daten in ZIP-Datei sichern',
      'import_data': 'Daten importieren',
      'import_data_desc': 'Daten aus Backup wiederherstellen',
      'export_success': 'Export erfolgreich!',
      'export_success_desc': 'Backup wurde erstellt. Du kannst es jetzt teilen oder speichern.',
      'export_error': 'Export fehlgeschlagen',
      'import_confirm': 'Backup importieren?',
      'import_confirm_desc': 'ACHTUNG: Alle aktuellen Daten werden gelöscht und durch das Backup ersetzt!',
      'import_success': 'Import erfolgreich! Alle Daten wurden wiederhergestellt.',
      'import_error': 'Import fehlgeschlagen',
      'backup_info': 'Backup-Informationen',
      'export_date': 'Export-Datum',
      'logs': 'Logs',
      'photos': 'Fotos',
      'share': 'Teilen',
      'close': 'Schließen',
      'import': 'Importieren',
      
      // Common
      'name': 'Name',
      'description': 'Beschreibung',
      'day': 'Tag',
      'days': 'Tage',
      'plant': 'Pflanze',
      'plants_count': 'Pflanzen',
      'no_data': 'Keine Daten',
      'loading': 'Lädt...',
      'error': 'Fehler',
      'without_grow': 'Ohne Grow',
      'unknown_grow': 'Unbekannter Grow',
      'unknown_strain': 'Unbekannte Sorte',
      
      // Messages
      'delete_confirm': 'Wirklich löschen?',
      'delete_plant_confirm': 'Möchtest du diese Pflanze wirklich löschen? Alle Logs werden ebenfalls gelöscht!',
      'deleted_success': 'Erfolgreich gelöscht!',
      'saved_success': 'Erfolgreich gespeichert!',
      
      // Empty States - Plants
      'no_plants_available': 'Keine Pflanzen vorhanden',
      'create_first_plant': 'Erstelle deine erste Pflanze!',
      
      // Empty States - Grows
      'no_grows': 'Keine Grows',
      'no_archived_grows': 'Keine archivierten Grows',
      'create_first_grow': 'Erstelle deinen ersten Grow!',
      'archive_grow_to_see': 'Archiviere einen Grow um ihn hier zu sehen',
      
      // Empty States - Rooms
      'no_rooms': 'Keine Räume',
      'add_first_room': 'Füge deinen ersten Grow-Raum hinzu!',
      
      // Empty States - Fertilizers
      'no_fertilizers': 'Keine Dünger',
      'add_first_fertilizer': 'Füge deinen ersten Dünger hinzu!',
      
      // Empty States - Hardware
      'no_hardware': 'Keine Hardware erfasst',
      'add_first_hardware': 'Füge die erste Hardware hinzu!',
      
      // Empty States - Harvests
      'no_harvests_yet': 'Noch keine Ernten',
      'no_harvests_found': 'Keine Ernten gefunden',
      'record_first_harvest': 'Erfasse deine erste Ernte!',
      'no_harvests_filter': 'Keine Ernten mit diesem Filter',
      
      // Harvest Filters
      'all': 'Alle',
      'in_drying': 'In Trocknung',
      'in_curing': 'In Curing',
      'completed': 'Abgeschlossen',
      
      // Actions (extended)
      'archive': 'Archivieren',
      'unarchive': 'Wiederherstellen',
      'show_archived': 'Archivierte anzeigen',
      'hide_archived': 'Archivierte ausblenden',
      'show_inactive': 'Inaktive anzeigen',
      'hide_inactive': 'Inaktive ausblenden',
      'activate': 'Aktivieren',
      'deactivate': 'Deaktivieren',
      
      // Confirms
      'attention': 'Achtung!',
      'delete_grow_title': 'Grow löschen?',
      'delete_grow_with_plants': 'Dieser Grow enthält noch {count} Pflanze(n). Wenn du ihn löschst, werden die Pflanzen vom Grow getrennt, aber nicht gelöscht.\n\nMöchtest du fortfahren?',
      'delete_room_title': 'Raum löschen?',
      'delete_room_with_plants': 'In "{name}" befinden sich noch {count} Pflanze(n). Bitte entferne zuerst alle Pflanzen oder weise sie einem anderen Raum zu.',
      'delete_fertilizer_title': 'Dünger löschen?',
      'delete_hardware_title': 'Hardware löschen?',
      'room_cannot_be_deleted': 'Raum kann nicht gelöscht werden',
      'yes_delete': 'Ja, löschen',
      'ok': 'OK',
      
      // Stats / Info
      'day_short': 'Tag',
      'plants_short': 'Pflanze(n)',
      'archived_badge': 'ARCHIVIERT',
      'total_wattage': 'Gesamt-Leistung',
      'hardware_items': 'Hardware-Items',

      // Legal & About
      'legal_about': 'Rechtliches & Info',
      'privacy_policy': 'Datenschutzerklärung',
      'privacy_policy_desc': 'Wie wir mit deinen Daten umgehen',
      'app_info': 'App-Information',
      'offline_badge': '100% Offline',
      'offline_badge_desc': 'Keine Datensammlung oder Tracking',

      // Database Management
      'data_management': 'Datenverwaltung',
      'reset_database': 'Alle Daten löschen',
      'reset_database_desc': 'Löscht ALLE Daten (Backup wird erstellt)',
      'reset_confirm_title': 'Alle Daten löschen?',
      'reset_confirm_message': 'ACHTUNG: Alle Daten werden PERMANENT gelöscht!\n\nVor dem Löschen wird automatisch ein Backup erstellt und auf deinem Gerät gespeichert.\n\nMöchtest du fortfahren?',
      'reset_success': 'Datenbank zurückgesetzt',
      'reset_success_desc': 'Backup wurde erstellt. Alle Daten wurden gelöscht.',
      'reset_error': 'Zurücksetzen fehlgeschlagen',
      'creating_backup': 'Erstelle Backup...',
      'backup_created': 'Backup erstellt',
    },
    
    // ENGLISH
    'en': {
      // Navigation
      'app_name': 'GrowLog',
      'dashboard': 'Dashboard',
      'plants': 'Plants',
      'grows': 'Grows',
      'rooms': 'Rooms',
      'fertilizers': 'Fertilizers',
      'hardware': 'Hardware',
      'harvests': 'Harvests',
      'settings': 'Settings',
      
      // Dashboard
      'welcome': 'Welcome',
      'overview': 'Overview',
      'statistics': 'Statistics',
      'active_grows': 'Active Grows',
      'total_plants': 'Total Plants',
      'active_plants': 'Active Plants',
      'plants_by_phase': 'Plants by Phase',
      'quick_actions': 'Quick Actions',
      'recent_activity': 'Recent Activity',
      
      // Statistics
      'total': 'Total',
      'active': 'Active',
      'archived': 'Archived',
      
      // Phases
      'seedling': 'Seedling',
      'veg': 'Vegetative',
      'bloom': 'Bloom',
      'harvest': 'Harvest',
      'phase_archived': 'Archived',
      
      // Actions
      'add_plant': 'Add Plant',
      'add_grow': 'Add Grow',
      'add_log': 'Add Log',
      'add_room': 'Add Room',
      'add_fertilizer': 'Add Fertilizer',
      'add_hardware': 'Add Hardware',
      'new_plant': 'New Plant',
      'delete': 'Delete',
      'edit': 'Edit',
      'save': 'Save',
      'cancel': 'Cancel',
      
      // Settings
      'language': 'Language',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'dark_mode_enabled': 'Dark Mode enabled 🌙',
      'light_mode_enabled': 'Light Mode enabled ☀️',
      'german': 'Deutsch',
      'english': 'English',

      // Backup & Restore
      'backup_restore': 'Backup & Restore',
      'export_data': 'Export Data',
      'export_data_desc': 'Save all data to ZIP file',
      'import_data': 'Import Data',
      'import_data_desc': 'Restore data from backup',
      'export_success': 'Export successful!',
      'export_success_desc': 'Backup created. You can now share or save it.',
      'export_error': 'Export failed',
      'import_confirm': 'Import backup?',
      'import_confirm_desc': 'WARNING: All current data will be deleted and replaced with the backup!',
      'import_success': 'Import successful! All data has been restored.',
      'import_error': 'Import failed',
      'backup_info': 'Backup Information',
      'export_date': 'Export Date',
      'logs': 'Logs',
      'photos': 'Photos',
      'share': 'Share',
      'close': 'Close',
      'import': 'Import',
      
      // Common
      'name': 'Name',
      'description': 'Description',
      'day': 'Day',
      'days': 'Days',
      'plant': 'Plant',
      'plants_count': 'Plants',
      'no_data': 'No data',
      'loading': 'Loading...',
      'error': 'Error',
      'without_grow': 'Without Grow',
      'unknown_grow': 'Unknown Grow',
      'unknown_strain': 'Unknown Strain',
      
      // Messages
      'delete_confirm': 'Really delete?',
      'delete_plant_confirm': 'Do you really want to delete this plant? All logs will be deleted too!',
      'deleted_success': 'Successfully deleted!',
      'saved_success': 'Successfully saved!',
      
      // Empty States - Plants
      'no_plants_available': 'No plants available',
      'create_first_plant': 'Create your first plant!',
      
      // Empty States - Grows
      'no_grows': 'No grows',
      'no_archived_grows': 'No archived grows',
      'create_first_grow': 'Create your first grow!',
      'archive_grow_to_see': 'Archive a grow to see it here',
      
      // Empty States - Rooms
      'no_rooms': 'No rooms',
      'add_first_room': 'Add your first grow room!',
      
      // Empty States - Fertilizers
      'no_fertilizers': 'No fertilizers',
      'add_first_fertilizer': 'Add your first fertilizer!',
      
      // Empty States - Hardware
      'no_hardware': 'No hardware recorded',
      'add_first_hardware': 'Add your first hardware!',
      
      // Empty States - Harvests
      'no_harvests_yet': 'No harvests yet',
      'no_harvests_found': 'No harvests found',
      'record_first_harvest': 'Record your first harvest!',
      'no_harvests_filter': 'No harvests with this filter',
      
      // Harvest Filters
      'all': 'All',
      'in_drying': 'Drying',
      'in_curing': 'Curing',
      'completed': 'Completed',
      
      // Actions (extended)
      'archive': 'Archive',
      'unarchive': 'Restore',
      'show_archived': 'Show archived',
      'hide_archived': 'Hide archived',
      'show_inactive': 'Show inactive',
      'hide_inactive': 'Hide inactive',
      'activate': 'Activate',
      'deactivate': 'Deactivate',
      
      // Confirms
      'attention': 'Attention!',
      'delete_grow_title': 'Delete grow?',
      'delete_grow_with_plants': 'This grow contains {count} plant(s). If you delete it, the plants will be detached from the grow but not deleted.\n\nDo you want to continue?',
      'delete_room_title': 'Delete room?',
      'delete_room_with_plants': '"{name}" still contains {count} plant(s). Please remove all plants first or assign them to another room.',
      'delete_fertilizer_title': 'Delete fertilizer?',
      'delete_hardware_title': 'Delete hardware?',
      'room_cannot_be_deleted': 'Room cannot be deleted',
      'yes_delete': 'Yes, delete',
      'ok': 'OK',
      
      // Stats / Info
      'day_short': 'Day',
      'plants_short': 'Plant(s)',
      'archived_badge': 'ARCHIVED',
      'total_wattage': 'Total Wattage',
      'hardware_items': 'Hardware Items',

      // Legal & About
      'legal_about': 'Legal & About',
      'privacy_policy': 'Privacy Policy',
      'privacy_policy_desc': 'How we handle your data',
      'app_info': 'App Information',
      'offline_badge': '100% Offline',
      'offline_badge_desc': 'No data collection or tracking',

      // Database Management
      'data_management': 'Data Management',
      'reset_database': 'Delete All Data',
      'reset_database_desc': 'Deletes ALL data (backup will be created)',
      'reset_confirm_title': 'Delete All Data?',
      'reset_confirm_message': 'WARNING: All data will be PERMANENTLY deleted!\n\nA backup will be automatically created and saved to your device before deletion.\n\nDo you want to continue?',
      'reset_success': 'Database reset',
      'reset_success_desc': 'Backup was created. All data has been deleted.',
      'reset_error': 'Reset failed',
      'creating_backup': 'Creating backup...',
      'backup_created': 'Backup created',
    },
  };

  String translate(String key) {
    return _translations[languageCode]?[key] ?? key;
  }

  // Shortcut for easier access
  String operator [](String key) => translate(key);
}
