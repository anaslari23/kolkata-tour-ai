import 'package:flutter/material.dart';
import '../models/place.dart';
import '../widgets/widgets.dart';
import '../services/api.dart';
import 'place_details_screen.dart';
import '../state/prefs.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

Future<void> apiClientUpdatePrefs(AppPrefs p) async {
  final api = const ApiService();
  try {
    await api.postJson('/prefs/update', {
      'user_id': 'A123',
      'preferences': p.toPrefsPayload(),
    });
  } catch (_) {}
}

void _openPrefs(BuildContext context) {
  final p = prefsNotifier.value;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
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
                    ChoiceChip(label: const Text('Calm'), selected: p.mood=='calm', onSelected: (_) { setSt(()=>p.mood='calm'); }),
                    ChoiceChip(label: const Text('Energetic'), selected: p.mood=='energetic', onSelected: (_) { setSt(()=>p.mood='energetic'); }),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Transport'),
                  Wrap(spacing: 8, children: [
                    for (final m in ['walk','scooter','car','metro'])
                      ChoiceChip(label: Text(m), selected: p.transportMode==m, onSelected: (_){ setSt(()=>p.transportMode=m); }),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Pace'),
                  Wrap(spacing: 8, children: [
                    for (final m in ['quick','normal','slow'])
                      ChoiceChip(label: Text(m), selected: p.pace==m, onSelected: (_){ setSt(()=>p.pace=m); }),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Walking distance (km)'),
                  Slider(value: p.walkingDistanceKm, min: 0.4, max: 3.0, divisions: 13, label: p.walkingDistanceKm.toStringAsFixed(1), onChanged: (v){ setSt(()=>p.walkingDistanceKm=double.parse(v.toStringAsFixed(1))); }),
                  const SizedBox(height: 10),
                  const Text('Available time (min)'),
                  Slider(value: p.availableTimeMin.toDouble(), min: 10, max: 120, divisions: 11, label: '${p.availableTimeMin}m', onChanged: (v){ setSt(()=>p.availableTimeMin=v.round()); }),
                  const SizedBox(height: 10),
                  const Text('Companion'),
                  Wrap(spacing: 8, children: [
                    for (final m in ['solo','couple','family','friends'])
                      ChoiceChip(label: Text(m), selected: p.companion==m, onSelected: (_){ setSt(()=>p.companion=m); }),
                  ]),
                  const SizedBox(height: 10),
                  SwitchListTile(title: const Text('Veg only'), value: p.vegOnly, onChanged: (v){ setSt(()=>p.vegOnly=v); }),
                  SwitchListTile(title: const Text('Street food OK'), value: p.streetFoodOk, onChanged: (v){ setSt(()=>p.streetFoodOk=v); }),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: (){
                      prefsNotifier.value = AppPrefs(
                        mood: p.mood,
                        interests: p.interests,
                        timePreference: p.timePreference,
                        transportMode: p.transportMode,
                        pace: p.pace,
                        availableTimeMin: p.availableTimeMin,
                        walkingDistanceKm: p.walkingDistanceKm,
                        companion: p.companion,
                        vegOnly: p.vegOnly,
                        streetFoodOk: p.streetFoodOk,
                      );
                      Navigator.pop(c);
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

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final messages = <Message>[
    const Message(isUser: false, text: 'Welcome to Kolkata! How can I help you explore the City of Joy today?'),
  ];
  bool typing = false;
  final api = const ApiService();

  void send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(Message(isUser: true, text: text));
      controller.clear();
      typing = true;
    });

    () async {
      try {
        final p = prefsNotifier.value;
        final reply = await api.chat(
          text,
          city: 'Kolkata',
          userId: 'A123',
          hour: DateTime.now().hour,
        );
        // push explicit prefs to backend (best-effort, non-blocking)
        () async {
          try {
            await apiClientUpdatePrefs(p);
          } catch (_) {}
        }();
        if (!mounted) return;
        setState(() { typing = false; messages.add(reply); });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          typing = false;
          messages.add(const Message(
            isUser: false,
            text: 'Here are some local picks — try asking for quiet heritage tea spots near the river. (Backend fallback engaged)'
          ));
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Kolkata Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _openPrefs(context),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (typing ? 1 : 0),
              itemBuilder: (c,i){
                if (typing && i == messages.length) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const SizedBox(
                          width: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Dot(), Dot(), Dot(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final m = messages[i];
                final align = m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                final bubbleColor = m.isUser ? Colors.amber.shade200 : Colors.grey.shade200;
                return Column(
                  crossAxisAlignment: align,
                  children: [
                    if (!m.isUser)
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 4),
                        child: Text('AI Guide', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(m.text),
                    ),
                    if (m.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(m.imageUrl!, width: 280),
                      ),
                    if (!m.isUser && (m.suggestions != null) && m.suggestions!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: SizedBox(
                          height: 210,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: m.suggestions!.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (c2, j) {
                              final p = m.suggestions![j];
                              return SizedBox(
                                width: 220,
                                child: PlaceCard(
                                  place: p,
                                  onTap: () {
                                    Navigator.push(c2, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)));
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          ChatInputBar(controller: controller, onSend: send, onMic: (){}),
        ],
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(3)),
    );
  }
}
