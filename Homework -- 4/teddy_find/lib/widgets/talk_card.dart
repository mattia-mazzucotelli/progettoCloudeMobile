import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/tedx_talk.dart';
import '../screens/talk_detail_screen.dart';
import 'tag_chip.dart';

class TalkCard extends StatelessWidget {
  final TedxTalk talk;
  final int index;

  const TalkCard({super.key, required this.talk, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TalkDetailScreen(talk: talk)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  _buildThumbnail(),
                  // Duration badge
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        talk.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Play button overlay
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE62B1E).withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic tag
                  if (talk.topic.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE62B1E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFE62B1E).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        talk.topic.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFE62B1E),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                  // Title
                  Text(
                    talk.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Speaker & Event
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${talk.speaker}  ·  ${talk.event}',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (talk.year > 0)
                        Text(
                          talk.year.toString(),
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),

                  // Tags
                  if (talk.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: talk.tags
                            .take(3)
                            .map((tag) => TagChip(label: tag))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (talk.thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: talk.thumbnailUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _shimmerPlaceholder(),
        errorWidget: (_, __, ___) => _fallbackThumbnail(),
      );
    }
    if (talk.youtubeId.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl:
            'https://img.youtube.com/vi/${talk.youtubeId}/maxresdefault.jpg',
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _shimmerPlaceholder(),
        errorWidget: (_, __, ___) => _fallbackThumbnail(),
      );
    }
    return _fallbackThumbnail();
  }

  Widget _shimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(height: 200, color: const Color(0xFF2A2A2A)),
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      height: 200,
      color: const Color(0xFF1A1A1A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient di sfondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A0A0A), Color(0xFF1A1A1A)],
              ),
            ),
          ),
          // Logo TED centrato
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE62B1E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  talk.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
