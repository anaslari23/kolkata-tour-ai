import 'package:flutter/material.dart';
import '../state/prefs.dart';
import '../services/api.dart';

Future<void> showPrefsSheet(BuildContext context) async {
  final p = prefsNotifier.value;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      AppPrefs tmp = AppPrefs(
        mood: p.mood,
        interests: List<String>.from(p.interests),
        timePreference: p.timePreference,
        transportMode: p.transportMode,
        pace: p.pace,
        availableTimeMin: p.availableTimeMin,
        walkingDistanceKm: p.walkingDistanceKm,
        companion: p.companion,
        vegOnly: p.vegOnly,
        streetFoodOk: p.streetFoodOk,
      );
      return StatefulBuilder(builder: (c, setSt) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('Calm'), selected: tmp.mood=='calm', onSelected: (_) { setSt(()=>tmp.mood='calm'); }),
                    ChoiceChip(label: const Text('Energetic'), selected: tmp.mood=='energetic', onSelected: (_) { setSt(()=>tmp.mood='energetic'); }),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Transport'),
                  Wrap(spacing: 8, children: [
                    for (final m in ['walk','scooter','car','metro'])
                      ChoiceChip(label: Text(m), selected: tmp.transportMode==m, onSelected: (_){ setSt(()=>tmp.transportMode=m); }),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Pace'),
                  Wrap(spacing: 8, children: [
                    for (final m in ['quick','normal','slow'])
                      ChoiceChip(label: Text(m), selected: tmp.pace==m, onSelected: (_){ setSt(()=>tmp.pace=m); }),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Walking distance (km)'),
                  Slider(value: tmp.walkingDistanceKm, min: 0.4, max: 3.0, divisions: 13, label: tmp.walkingDistanceKm.toStringAsFixed(1), onChanged: (v){ setSt(()=>tmp.walkingDistanceKm=double.parse(v.toStringAsFixed(1))); }),
                  const SizedBox(height: 10),
                  const Text('Available time (min)'),
                  Slider(value: tmp.availableTimeMin.toDouble(), min: 10, max: 120, divisions: 11, label: '${tmp.availableTimeMin}m', onChanged: (v){ setSt(()=>tmp.availableTimeMin=v.round()); }),
                  const SizedBox(height: 10),
                  const Text('Companion'),
                  Wrap(spacing: 8, children: [
                    for (final m in ['solo','couple','family','friends'])
                      ChoiceChip(label: Text(m), selected: tmp.companion==m, onSelected: (_){ setSt(()=>tmp.companion=m); }),
                  ]),
                  const SizedBox(height: 10),
                  SwitchListTile(title: const Text('Veg only'), value: tmp.vegOnly, onChanged: (v){ setSt(()=>tmp.vegOnly=v); }),
                  SwitchListTile(title: const Text('Street food OK'), value: tmp.streetFoodOk, onChanged: (v){ setSt(()=>tmp.streetFoodOk=v); }),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      prefsNotifier.value = tmp;
                      await savePrefs(tmp);
                      try {
                        await ApiService().postJson('/prefs/update', {
                          'user_id': 'A123',
                          'preferences': tmp.toPrefsPayload(),
                        });
                      } catch (_) {}
                      if (c.mounted) Navigator.pop(c);
                    },
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save'),
                  )
                ],
              ),
            ),
          ),
        );
      });
    },
  );
}
