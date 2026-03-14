import 'package:growlog_app/models/fertilizer.dart';

class PrefilledFertilizers {
  static final List<Fertilizer> all = [
    // --- HESI ---
    Fertilizer(brand: 'Hesi', name: 'TNT Complex', npk: '3-2-3', type: 'Wachstum'),
    Fertilizer(brand: 'Hesi', name: 'Blüh-Complex', npk: '3-3-4', type: 'Blüte'),
    Fertilizer(brand: 'Hesi', name: 'Phosphor Plus', npk: '0-7-5', type: 'Blüte-Booster'),
    Fertilizer(brand: 'Hesi', name: 'Hesi Boost', npk: '0-1-1', type: 'Booster'),
    Fertilizer(brand: 'Hesi', name: 'Wurzel-Complex', type: 'Wurzelstimulator'),
    Fertilizer(brand: 'Hesi', name: 'PowerZyme', type: 'Enzyme'),
    Fertilizer(brand: 'Hesi', name: 'SuperVit', type: 'Vitamine / Aminosäuren'),

    // --- CANNA ---
    Fertilizer(brand: 'CANNA', name: 'Terra Vega', npk: '3-1-4', type: 'Wachstum'),
    Fertilizer(brand: 'CANNA', name: 'Terra Flores', npk: '2-2-4', type: 'Blüte'),
    Fertilizer(brand: 'CANNA', name: 'Aqua Vega A+B', npk: '6-3-8', type: 'Hydro Wachstum'),
    Fertilizer(brand: 'CANNA', name: 'Aqua Flores A+B', npk: '4-4-11', type: 'Hydro Blüte'),
    Fertilizer(brand: 'CANNA', name: 'Rhizotonic', type: 'Wurzelstimulator'),
    Fertilizer(brand: 'CANNA', name: 'Cannazym', type: 'Enzyme'),
    Fertilizer(brand: 'CANNA', name: 'PK 13/14', npk: '0-13-14', type: 'Booster'),
    Fertilizer(brand: 'CANNA', name: 'Canna Boost', type: 'Blühbeschleuniger'),

    // --- BIOBIZZ ---
    Fertilizer(brand: 'BioBizz', name: 'Bio-Grow', npk: '4-3-6', type: 'Bio Wachstum'),
    Fertilizer(brand: 'BioBizz', name: 'Bio-Bloom', npk: '2-7-4', type: 'Bio Blüte'),
    Fertilizer(brand: 'BioBizz', name: 'Top-Max', type: 'Blüh-Stimulator'),
    Fertilizer(brand: 'BioBizz', name: 'Root-Juice', type: 'Wurzelstimulator'),
    Fertilizer(brand: 'BioBizz', name: 'Alg-A-Mic', type: 'Vitalstoff'),
    Fertilizer(brand: 'BioBizz', name: 'Fish-Mix', npk: '5-1-4', type: 'Wachstum (Outdoor)'),

    // --- ADVANCED NUTRIENTS (pH Perfect) ---
    Fertilizer(brand: 'Advanced Nutrients', name: 'Sensi Grow A', npk: '3-0-0', type: 'Wachstum'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Sensi Grow B', npk: '1-2-6', type: 'Wachstum'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Sensi Bloom A', npk: '3-0-0', type: 'Blüte'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Sensi Bloom B', npk: '2-4-8', type: 'Blüte'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Big Bud', npk: '0-1-3', type: 'Booster'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Overdrive', npk: '1-5-4', type: 'Spätblüte Booster'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Voodoo Juice', type: 'Wurzelstimulator'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'Bud Candy', type: 'Kohlenhydrate / Geschmack'),
    Fertilizer(brand: 'Advanced Nutrients', name: 'B-52', npk: '2-1-4', type: 'Vitamin B / Stressschutz'),

    // --- PLAGRON ---
    Fertilizer(brand: 'Plagron', name: 'Alga Grow', npk: '4-2-4', type: 'Bio Wachstum'),
    Fertilizer(brand: 'Plagron', name: 'Alga Bloom', npk: '3-2-5', type: 'Bio Blüte'),
    Fertilizer(brand: 'Plagron', name: 'Terra Grow', npk: '3-1-3', type: 'Wachstum'),
    Fertilizer(brand: 'Plagron', name: 'Terra Bloom', npk: '2-2-4', type: 'Blüte'),
    Fertilizer(brand: 'Plagron', name: 'Power Roots', npk: '1-0-2', type: 'Wurzelstimulator'),
    Fertilizer(brand: 'Plagron', name: 'Green Sensation', npk: '0-9-10', type: '4-in-1 Booster'),
    Fertilizer(brand: 'Plagron', name: 'Sugar Royal', npk: '9-0-0', type: 'Geschmacks-Optimierer'),

    // --- BIOTABS ---
    Fertilizer(brand: 'BioTabs', name: 'BioTabs (Tabletten)', npk: '15-7-8', type: 'Langzeitdünger'),
    Fertilizer(brand: 'BioTabs', name: 'Startrex', npk: '3-1-2', type: 'Bodenverbesserer'),
    Fertilizer(brand: 'BioTabs', name: 'Orgatrex', npk: '5-1-5', type: 'Flüssigdünger'),
    Fertilizer(brand: 'BioTabs', name: 'Bactrex', type: 'Bakterien'),
    Fertilizer(brand: 'BioTabs', name: 'Mycotrex', type: 'Mykorrhiza'),

    // --- GREENHOUSE FEEDING ---
    Fertilizer(brand: 'Greenhouse', name: 'Powder Feeding Grow', npk: '24-6-12', type: 'Pulver Wachstum'),
    Fertilizer(brand: 'Greenhouse', name: 'Powder Feeding Hybrids', npk: '15-7-22', type: 'Pulver Hybrid'),
    Fertilizer(brand: 'Greenhouse', name: 'Powder Feeding Short Flowering', npk: '16-6-26', type: 'Pulver Indica'),
    Fertilizer(brand: 'Greenhouse', name: 'BioGrow', npk: '7-2-4', type: 'Bio Pulver Wachstum'),
    Fertilizer(brand: 'Greenhouse', name: 'BioBloom', npk: '4-9-9', type: 'Bio Pulver Blüte'),

    // --- ATHENA (Professional Line) ---
    Fertilizer(brand: 'Athena', name: 'Pro Core', npk: '14-0-0', n: 14.0, ca: 17.0, type: 'Basis'),
    Fertilizer(brand: 'Athena', name: 'Pro Grow', npk: '2-8-20', p: 8.0, k: 20.0, mg: 3.0, s: 5.0, type: 'Wachstum'),
    Fertilizer(brand: 'Athena', name: 'Pro Bloom', npk: '0-12-24', p: 12.0, k: 24.0, mg: 3.0, s: 5.0, type: 'Blüte'),
    // --- ATHENA (Blended Line) ---
    Fertilizer(brand: 'Athena', name: 'Grow A', npk: '3-0-0', n: 3.0, ca: 3.0, type: 'Wachstum A'),
    Fertilizer(brand: 'Athena', name: 'Grow B', npk: '1-3-5', n: 1.0, p: 3.0, k: 5.0, type: 'Wachstum B'),
    Fertilizer(brand: 'Athena', name: 'Bloom A', npk: '3-0-0', n: 3.0, ca: 3.0, type: 'Blüte A'),
    Fertilizer(brand: 'Athena', name: 'Bloom B', npk: '0-6-5', p: 6.0, k: 5.0, type: 'Blüte B'),
    Fertilizer(brand: 'Athena', name: 'Clean', type: 'Systemreiniger'),
    Fertilizer(brand: 'Athena', name: 'Stack', type: 'Blüh-Stimulator'),

    // --- VEG+BLOOM (V+B / VBX) ---
    Fertilizer(brand: 'Veg+Bloom', name: 'Dirty', npk: '0-12-15', type: 'Ein-Komponenten (Erde/Coco)'),
    Fertilizer(brand: 'Veg+Bloom', name: 'RO/Soft', npk: '0-12-15', type: 'Ein-Komponenten (Hydro RO)'),
    Fertilizer(brand: 'Veg+Bloom', name: 'Tap/Hard', npk: '0-12-15', type: 'Ein-Komponenten (Leitungswasser)'),
    Fertilizer(brand: 'Veg+Bloom', name: 'VBX', npk: '8-15-20', type: 'Professional Concentrated Salt'),
    Fertilizer(brand: 'Veg+Bloom', name: 'Shine', npk: '0-22-12', type: 'Blüte-Booster'),
  ];
}
