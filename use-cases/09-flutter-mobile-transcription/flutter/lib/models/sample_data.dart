import 'history_item.dart';

/// Demo content ported from the reference `history.html` dataset.
const List<String> historyBuckets = ['today', 'yesterday', 'week', 'month'];

const Map<String, String> bucketLabels = {
  'today': 'Today',
  'yesterday': 'Yesterday',
  'week': 'Earlier this week',
  'month': 'Last month',
};

final List<HistoryItem> sampleHistory = [
  HistoryItem(
    id: '1',
    type: HistoryType.batch,
    title: 'Travel Assistance',
    jobId:'003',
    languages: const ['EN', 'ES'],
    arrow: '→',
    relativeLabel: '2m ago',
    bucket: 'today',
    duration: '0:12',
    translation: true,
    speakers: 2,
    segments: const [
      TranscriptSegment(speaker: 'Speaker 1', time: '00:00', parts: [
        TranscriptPart('EN', 'I really need to get to the'),
        TranscriptPart('ES', 'estación central'),
        TranscriptPart('EN', ', but my train leaves in five minutes.'),
      ]),
      TranscriptSegment(speaker: 'Speaker 2', time: '00:05', parts: [
        TranscriptPart('EN', 'Which station are you looking for?'),
      ]),
      TranscriptSegment(speaker: 'Speaker 1', time: '00:08', parts: [
        TranscriptPart('EN', 'Atocha. Can you help me get there fast?'),
      ]),
    ],
    translationText:
        'I really need to get to the central station, but my train leaves in five minutes. Which station are you looking for? Atocha. Can you help me get there fast?',
  ),
  HistoryItem(
    id: '2',
    type: HistoryType.conversation,
    title: 'Tokyo Market Interview',
    jobId:'004',
    languages: const ['EN', 'JA'],
    arrow: '↔',
    relativeLabel: '1h ago',
    bucket: 'today',
    duration: '3:18',
    translation: true,
    turns: 6,
    conversation: const [
      ConversationTurn(role: 'User', lang: 'EN', text: 'Is there a pharmacy nearby?'),
      ConversationTurn(role: 'A', lang: 'JA', text: '近くに薬局があります。'),
      ConversationTurn(role: 'User', lang: 'EN', text: 'How do I get there?'),
      ConversationTurn(role: 'A', lang: 'JA', text: '二つ目の角を右に曲がってください。'),
      ConversationTurn(role: 'User', lang: 'EN', text: 'Thank you so much!'),
      ConversationTurn(role: 'A', lang: 'JA', text: 'どういたしまして。'),
    ],
  ),
  HistoryItem(
    id: '3',
    type: HistoryType.batch,
    title: 'Customer Support Call',
    jobId:'005',
    languages: const ['EN', 'FR'],
    arrow: '→',
    relativeLabel: 'Yesterday',
    bucket: 'yesterday',
    duration: '1:42',
    translation: true,
    speakers: 1,
    segments: const [
      TranscriptSegment(speaker: 'Speaker 1', time: '00:00', parts: [
        TranscriptPart('EN', 'I would like to order a coffee, please.'),
      ]),
      TranscriptSegment(speaker: 'Speaker 1', time: '00:04', parts: [
        TranscriptPart('EN', 'With oat milk if possible.'),
      ]),
    ],
    translationText:
        "Je voudrais commander un café, s'il vous plaît. Avec du lait d'avoine si possible.",
  ),
  HistoryItem(
    id: '4',
    type: HistoryType.batch,
    title: 'Navigation Inquiry',
    jobId:'006',
    languages: const ['JA', 'EN'],
    arrow: '→',
    relativeLabel: 'Yesterday',
    bucket: 'yesterday',
    duration: '0:08',
    translation: true,
    segments: const [
      TranscriptSegment(speaker: 'Speaker 1', time: '00:00', parts: [
        TranscriptPart('JA', 'はい、二つ目の角にあります。'),
      ]),
    ],
    translationText: "Yes, it's at the second corner.",
  ),
  HistoryItem(
    id: '5',
    type: HistoryType.conversation,
    title: 'Berlin Pharmacy Run',
    jobId:'007',
    languages: const ['DE', 'EN'],
    arrow: '↔',
    relativeLabel: '4d ago',
    bucket: 'week',
    duration: '5:21',
    translation: true,
    turns: 12,
    conversation: const [
      ConversationTurn(role: 'User', lang: 'DE', text: 'Wo ist die nächste Apotheke?'),
      ConversationTurn(role: 'A', lang: 'EN', text: "There's one two blocks down on the left."),
      ConversationTurn(role: 'User', lang: 'DE', text: 'Hat sie jetzt geöffnet?'),
      ConversationTurn(role: 'A', lang: 'EN', text: 'Yes, until 8 PM tonight.'),
    ],
  ),
  HistoryItem(
    id: '6',
    type: HistoryType.batch,
    title: 'Quarterly Strategy Meeting',
    jobId:'001',
    languages: const ['EN'],
    relativeLabel: '20d ago',
    bucket: 'month',
    duration: '42:10',
    speakers: 4,
    segments: const [
      TranscriptSegment(speaker: 'Speaker 1', time: '00:00', parts: [
        TranscriptPart('EN',
            'The focus for next year is linguistic precision and multi-language support across all our endpoints.'),
      ]),
      TranscriptSegment(speaker: 'Speaker 2', time: '00:14', parts: [
        TranscriptPart('EN', 'Agreed. We need to prioritize Melia integration in Q1.'),
      ]),
      TranscriptSegment(speaker: 'Speaker 3', time: '00:28', parts: [
        TranscriptPart('EN', "What's the latency target for real-time?"),
      ]),
      TranscriptSegment(speaker: 'Speaker 1', time: '00:32', parts: [
        TranscriptPart('EN', 'Under 300 ms end-to-end.'),
      ]),
    ],
  ),
];
