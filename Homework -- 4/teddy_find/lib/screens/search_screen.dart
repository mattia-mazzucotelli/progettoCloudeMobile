import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/tedx_talk.dart';
import '../services/lambda_service.dart';
import '../widgets/talk_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<TedxTalk> _results = [];
  List<TedxTalk> _featured = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  String _lastQuery = '';

  // Suggested topics shown nella home
  final List<String> _suggestions = [
    'Artificial Intelligence',
    'Climate Change',
    'Mental Health',
    'Future of Work',
    'Creativity',
    'Leadership',
    'Science',
    'Education',
    'Innovation',
    'Space',
  ];

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    final talks = await LambdaService.getFeaturedTalks();
    if (mounted) setState(() => _featured = talks);
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
      _lastQuery = query;
    });

    try {
      final results = await LambdaService.searchTalks(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
      _errorMessage = '';
      _lastQuery = '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Center(
        child: Image.asset(
          'assets/images/teddy_nobg.png',
          fit: BoxFit.contain,
          height: 110,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focusNode.hasFocus
                ? const Color(0xFFE62B1E).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE62B1E).withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF666666),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                decoration: const InputDecoration(
                  hintText: 'Cerca un talk TEDx...',
                  hintStyle: TextStyle(color: Color(0xFF555555), fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF555555),
                  size: 18,
                ),
                onPressed: _clearSearch,
              ),
            GestureDetector(
              onTap: () => _search(_controller.text),
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE62B1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Cerca',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: -0.1);
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_errorMessage.isNotEmpty) return _buildError();
    if (_hasSearched) return _buildResults();
    return _buildHome();
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Heading
          const Text(
            'Esplora i Talk TEDx',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

          const SizedBox(height: 6),
          const Text(
            'Cerca per argomento, frase o speaker',
            style: TextStyle(color: Color(0xFF666666), fontSize: 14),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 20),

          // Suggestion chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .asMap()
                .entries
                .map(
                  (e) => _SuggestionChip(
                    label: e.value,
                    onTap: () {
                      _controller.text = e.value;
                      _search(e.value);
                    },
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 300 + e.key * 50),
                      )
                      .scale(begin: const Offset(0.8, 0.8)),
                )
                .toList(),
          ),

          if (_featured.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              'In Evidenza',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 4),
            ..._featured.asMap().entries.map(
                  (e) => TalkCard(talk: e.value, index: e.key)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 700 + e.key * 80))
                      .slideY(begin: 0.1),
                ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF444444),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun risultato per\n"$_lastQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _clearSearch,
              child: const Text(
                'Prova un\'altra ricerca',
                style: TextStyle(color: Color(0xFFE62B1E)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            '${_results.length} risultati per "$_lastQuery"',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            itemCount: _results.length,
            itemBuilder: (context, index) =>
                TalkCard(talk: _results[index], index: index)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: index * 60))
                    .slideY(begin: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: 5,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFE62B1E),
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Errore di connessione',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _search(_lastQuery),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE62B1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
        duration: 1200.ms, color: Colors.white.withValues(alpha: 0.05));
  }
}
