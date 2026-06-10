class TedxTalk {
  final String id;
  final String title;
  final String speaker;
  final String description;
  final String topic;
  final String duration;
  final String thumbnailUrl;
  final String videoUrl;
  final String youtubeId;
  final int year;
  final String event;
  final List<String> tags;
  final List<String> watchNext;

  TedxTalk({
    required this.id,
    required this.title,
    required this.speaker,
    required this.description,
    required this.topic,
    required this.duration,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.youtubeId,
    required this.year,
    required this.event,
    required this.tags,
    required this.watchNext,
  });

  factory TedxTalk.fromJson(Map<String, dynamic> json) {
    // La Lambda restituisce i dati annidati in json['talk'].
    // Se il campo 'talk' non esiste (risposta piatta), usa json direttamente.
    final Map<String, dynamic> talk =
        (json['talk'] as Map<String, dynamic>?) ?? json;

    // L'id del chunk ChromaDB è in json['id'], quello del talk in talk['id']
    final String talkId =
        talk['id']?.toString() ?? json['id']?.toString() ?? '';

    // La thumbnail: prova thumbnail_url, poi costruisce da YouTube se c'è youtubeId
    final String youtubeId = talk['youtube_id']?.toString() ?? '';
    String thumbnailUrl = talk['thumbnail_url']?.toString() ?? '';
    if (thumbnailUrl.isEmpty && youtubeId.isNotEmpty) {
      thumbnailUrl = 'https://img.youtube.com/vi/$youtubeId/maxresdefault.jpg';
    }

    // publishedAt → year (es. "2025-03-07T17:25:46Z" → 2025)
    int year = 0;
    final String? publishedAt = talk['publishedAt']?.toString();
    if (publishedAt != null && publishedAt.length >= 4) {
      year = int.tryParse(publishedAt.substring(0, 4)) ?? 0;
    }

    // duration in secondi → formato "MM:SS"
    String duration = talk['duration']?.toString() ?? '';
    final int? durationSec = int.tryParse(duration);
    if (durationSec != null) {
      final int m = durationSec ~/ 60;
      final int s = durationSec % 60;
      duration = '$m:${s.toString().padLeft(2, '0')}';
    }

    // watch_next: lista di ID stringa
    final List<String> watchNext = List<String>.from(
      (talk['watch_next'] as List<dynamic>?)?.map((e) => e.toString()) ?? [],
    );

    return TedxTalk(
      id: talkId,
      title: talk['title']?.toString() ?? '',
      speaker:
          talk['speaker']?.toString() ?? talk['speakers']?.toString() ?? '',
      description: talk['description']?.toString() ?? '',
      topic: talk['topic']?.toString() ?? '',
      duration: duration,
      thumbnailUrl: thumbnailUrl,
      videoUrl: talk['url']?.toString() ?? '', // url TED → videoUrl
      youtubeId: youtubeId,
      year: year,
      event: talk['event']?.toString() ?? '',
      tags: List<String>.from(talk['tags'] ?? []),
      watchNext: watchNext,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'speaker': speaker,
        'description': description,
        'topic': topic,
        'duration': duration,
        'thumbnail_url': thumbnailUrl,
        'video_url': videoUrl,
        'youtube_id': youtubeId,
        'year': year,
        'event': event,
        'tags': tags,
        'watch_next': watchNext,
      };
}
