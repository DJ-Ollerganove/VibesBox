/**
 * VibesBox Theme - Zentrale Farbvariablen
 * Diese Datei enthält alle Design-Farben für die PWA
 */

const VIBESBOX_THEME = {
  // ✅ Haupt-Orange (Primary Orange)
  ORANGE_PRIMARY: '#FFA500',
  
  // ✅ Schwaches Orange für Input-Hintergründe (10-15% Deckkraft)
  ORANGE_BG_SUBTLE: 'rgba(255, 165, 0, 0.12)',
  
  // ✅ Grün für Erfolg/Absendebutton
  GREEN_SUCCESS: '#28a745',
  GREEN_SUCCESS_HOVER: '#218838',
  
  // ✅ Weitere Farben (für Konsistenz)
  BLACK_BACKGROUND: '#000000',
  WHITE_TEXT: '#FFFFFF',
  GRAY_TEXT: '#E5E7EB',
  
  // ✅ Orange-Varianten für Hover/Active
  ORANGE_DARK: '#FF8C00',
  ORANGE_LIGHT: 'rgba(255, 165, 0, 0.4)',
};

// ✅ Globale Verfügbarkeit
if (typeof window !== 'undefined') {
  window.VIBESBOX_THEME = VIBESBOX_THEME;
}

// ✅ Export für Module (falls benötigt)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = VIBESBOX_THEME;
}
