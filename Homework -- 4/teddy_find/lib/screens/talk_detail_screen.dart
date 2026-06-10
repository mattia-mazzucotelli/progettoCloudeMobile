import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/tedx_talk.dart';
import '../widgets/tag_chip.dart';
import '../services/lambda_service.dart';

class TalkDetailScreen extends StatefulWidget {
  final TedxTalk talk;
  const TalkDetailScreen({super.key, required this.talk});

  @override
  State<TalkDetailScreen> createState() => _TalkDetailScreenState();
}

class _TalkDetailScreenState extends State<TalkDetailScreen> {
  YoutubePlayerController? _ytController;
  bool _showPlayer = false;

  // Watch Next state
  List<TedxTalk> _watchNextTalks = [];
  bool _loadingWatchNext = true;
  bool _watchNextError = false;

  @override
  void initState() {
    super.initState();
    if (widget.talk.youtubeId.isNotEmpty) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.talk.youtubeId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
        ),
      );
    }
    _loadWatchNext();
  }

  @override
  void didUpdateWidget(TalkDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ricarica tutto se si naviga verso un talk diverso
    if (oldWidget.talk.id != widget.talk.id) {
      _ytController?.dispose();
      if (widget.talk.youtubeId.isNotEmpty) {
        _ytController = YoutubePlayerController(
          initialVideoId: widget.talk.youtubeId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
          ),
        );
      } else {
        _ytController = null;
      }
      setState(() {
        _showPlayer = false;
        _watchNextTalks = [];
        _loadingWatchNext = true;
        _watchNextError = false;
      });
      _loadWatchNext();
    }
  }

  Future<void> _loadWatchNext() async {
    try {
      final talks = await LambdaService.getWatchNext(widget.talk.id, n: 6);
      debugPrint('✅ watchNext: ${talks.length} talks');
      for (final t in talks) {
        debugPrint('  → ${t.id} | ${t.title}');
      }
      if (mounted) {
        setState(() {
          _watchNextTalks = talks;
          _loadingWatchNext = false;
        });
      }
    } catch (e) {
      debugPrint('❌ watchNext error: $e');
      if (mounted) {
        setState(() {
          _loadingWatchNext = false;
          _watchNextError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    final url = widget.talk.videoUrl.isNotEmpty
        ? widget.talk.videoUrl
        : widget.talk.youtubeId.isNotEmpty
            ? 'https://www.youtube.com/watch?v=${widget.talk.youtubeId}'
            : null;

    if (url == null) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _share() {
    final url = widget.talk.youtubeId.isNotEmpty
        ? 'https://www.youtube.com/watch?v=${widget.talk.youtubeId}'
        : widget.talk.videoUrl;
    Share.share(
      '🎤 "${widget.talk.title}" — ${widget.talk.speaker}\n\n$url\n\nTrovato su TeddyFind',
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller:
            _ytController ?? YoutubePlayerController(initialVideoId: ''),
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFFE62B1E),
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, player),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildMetaRow(),
                      const SizedBox(height: 20),
                      _buildInfoCards(),
                      const SizedBox(height: 24),
                      _buildDescription(),
                      if (widget.talk.tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildTags(),
                      ],
                      const SizedBox(height: 32),
                      _buildActions(),
                      const SizedBox(height: 32),
                      _buildWatchNext(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailFallback() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A0A0A), Color(0xFF1A1A1A)],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE62B1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.talk.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Widget player) {
    return SliverAppBar(
      expandedHeight: _showPlayer ? null : 260,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F0F),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _share,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _showPlayer && _ytController != null
            ? Container(
                color: Colors.black,
                child: Center(child: player),
              )
            : _buildThumbnailHero(),
      ),
    );
  }

  Widget _buildThumbnailHero() {
    final hasYoutube = widget.talk.youtubeId.isNotEmpty;
    final thumbUrl = widget.talk.thumbnailUrl.isNotEmpty
        ? widget.talk.thumbnailUrl
        : hasYoutube
            ? 'https://img.youtube.com/vi/${widget.talk.youtubeId}/maxresdefault.jpg'
            : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbUrl != null)
          Image.network(
            thumbUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildThumbnailFallback(),
          )
        else
          _buildThumbnailFallback(),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                const Color(0xFF0F0F0F).withValues(alpha: 0.9),
              ],
            ),
          ),
        ),

        // Play button
        if (_ytController != null)
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _showPlayer = true),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE62B1E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE62B1E).withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 1500.ms,
                  curve: Curves.easeInOut,
                ),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.talk.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE62B1E).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE62B1E).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: Color(0xFFE62B1E),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.talk.speaker,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.talk.event.isNotEmpty)
                Text(
                  widget.talk.event,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildInfoCards() {
    final items = [
      if (widget.talk.duration.isNotEmpty)
        _InfoItem(
          icon: Icons.schedule_rounded,
          label: 'Durata',
          value: widget.talk.duration,
        ),
      if (widget.talk.topic.isNotEmpty)
        _InfoItem(
          icon: Icons.category_rounded,
          label: 'Tema',
          value: widget.talk.topic,
        ),
      if (widget.talk.year > 0)
        _InfoItem(
          icon: Icons.calendar_today_rounded,
          label: 'Anno',
          value: widget.talk.year.toString(),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 16, color: const Color(0xFFE62B1E)),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildDescription() {
    if (widget.talk.description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descrizione',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.talk.description,
          style: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tag',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: widget.talk.tags.map((t) => TagChip(label: t)).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildActions() {
    final hasVideo =
        widget.talk.videoUrl.isNotEmpty || widget.talk.youtubeId.isNotEmpty;
    final hasYoutube = widget.talk.youtubeId.isNotEmpty;

    return Column(
      children: [
        if (hasYoutube && !_showPlayer)
          _ActionButton(
            icon: Icons.play_circle_fill_rounded,
            label: 'Guarda il Talk',
            isPrimary: true,
            onTap: () {
              setState(() => _showPlayer = true);
              // Scroll to top to show player
              PrimaryScrollController.maybeOf(context)?.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
        const SizedBox(height: 10),
        if (hasVideo)
          _ActionButton(
            icon: Icons.open_in_new_rounded,
            label: 'Apri su YouTube',
            isPrimary: false,
            onTap: _openLink,
          ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'Condividi',
          isPrimary: false,
          onTap: _share,
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1);
  }

  Widget _buildWatchNext() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE62B1E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Guarda anche',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content
        if (_loadingWatchNext)
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (_, __) => _WatchNextSkeletonCard(),
            ),
          )
        else if (_watchNextError || _watchNextTalks.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _watchNextTalks.length,
              itemBuilder: (context, i) => _WatchNextCard(
                talk: _watchNextTalks[i],
              ).animate().fadeIn(delay: Duration(milliseconds: 80 * i)),
            ),
          ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem({required this.icon, required this.label, required this.value});
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color:
                isPrimary ? const Color(0xFFE62B1E) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : const Color(0xFFCCCCCC),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : const Color(0xFFCCCCCC),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Watch Next card (orizzontale) ───────────────────────────────────────────

class _WatchNextCard extends StatelessWidget {
  final TedxTalk talk;
  const _WatchNextCard({required this.talk});

  @override
  Widget build(BuildContext context) {
    final thumbUrl = talk.thumbnailUrl.isNotEmpty
        ? talk.thumbnailUrl
        : talk.youtubeId.isNotEmpty
            ? 'https://img.youtube.com/vi/${talk.youtubeId}/mqdefault.jpg'
            : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TalkDetailScreen(talk: talk)),
      ),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  if (thumbUrl != null)
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      height: 110,
                      width: 180,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _fallback(),
                    )
                  else
                    _fallback(),
                  // Play overlay
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE62B1E).withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  // Duration badge
                  if (talk.duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          talk.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    talk.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    talk.speaker,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        height: 110,
        width: 180,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A0A0A), Color(0xFF1A1A1A)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE62B1E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                talk.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Skeleton loading card ────────────────────────────────────────────────────

class _WatchNextSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(height: 110, color: const Color(0xFF2A2A2A)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
          duration: 1200.ms,
          color: Colors.white.withValues(alpha: 0.04),
        );
  }
}
