import 'package:flutter/material.dart';
import '../models/place.dart';
import '../widgets/widgets.dart';
import '../services/api.dart';
import 'place_details_screen.dart';
import '../state/prefs.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

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
  late final stt.SpeechToText _stt;
  bool _sttAvailable = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _stt = stt.SpeechToText();
    () async {
      try {
        if (kIsWeb) {
          _sttAvailable = false; // speech_to_text not supported on web in this build
        } else {
          _sttAvailable = await _stt.initialize(onStatus: (_) {}, onError: (_) {});
        }
      } catch (_) {
        _sttAvailable = false;
      }
      if (mounted) setState(() {});
    }();
  }

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(radius: 14, child: Icon(Icons.android, size: 16)),
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const SizedBox(
                          width: 44,
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
                final theme = Theme.of(context);
                final isUser = m.isUser;
                final bubbleColor = isUser ? theme.colorScheme.secondaryContainer : Colors.grey.shade200;
                final textColor = isUser ? theme.colorScheme.onSecondaryContainer : Colors.black87;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        const CircleAvatar(radius: 14, child: Icon(Icons.android, size: 16)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isUser)
                              const Padding(
                                padding: EdgeInsets.only(left: 6, bottom: 4),
                                child: Text('AI Guide', style: TextStyle(color: Colors.black54, fontSize: 12)),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                                  bottomRight: Radius.circular(isUser ? 4 : 14),
                                ),
                              ),
                              child: Text(m.text, style: TextStyle(color: textColor)),
                            ),
                            if (m.imageUrl != null) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(m.imageUrl!, width: 280),
                              ),
                            ],
                            if (!isUser && (m.suggestions != null) && m.suggestions!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
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
                            ],
                          ],
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          ChatInputBar(controller: controller, onSend: send, onMic: _onMic),
        ],
      ),
    );
  }

  void _onMic() async {
    if (!_sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speech not available on this device')));
      return;
    }
    if (_listening) {
      await _stt.stop();
      setState(() { _listening = false; });
      return;
    }
    try {
      setState(() { _listening = true; });
      await _stt.listen(onResult: (res) {
        final text = res.recognizedWords;
        if (text.isNotEmpty) {
          controller.text = text;
        }
        if (res.finalResult) {
          setState(() { _listening = false; });
          _stt.stop();
          if (controller.text.trim().isNotEmpty) send();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _listening = false; _sttAvailable = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mic permission denied or unavailable')));
    }
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
