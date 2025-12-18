// lib/widgets/latest_news_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// alias the model file (preferred for types)
import '../models/news_item.dart' as model;

// alias the service file (preferred for helpers)
import '../services/news_service.dart' as news_service;

class LatestNewsWidget extends StatefulWidget {
  const LatestNewsWidget({super.key, this.limit = 3});
  final int limit;

  @override
  State<LatestNewsWidget> createState() => _LatestNewsWidgetState();
}

class _LatestNewsWidgetState extends State<LatestNewsWidget> {
  final news_service.NewsService _newsService = news_service.NewsService();

  bool _loading = true;
  List<model.NewsItem> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _newsService.fetchLatest(limit: widget.limit);
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _placeholderImage(double height) {
      return Container(
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.article_outlined, size: height * 0.32, color: Colors.grey[500]),
      ),
    );
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open article')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open article')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // responsive height: fixed but conservative to avoid overflow
    final containerHeight = 150.0;

    if (_loading) {
      return SizedBox(
        height: containerHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text('News error: $_error', style: const TextStyle(color: Colors.red))),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('No recent scam news found.')),
            TextButton(onPressed: _load, child: const Text('Refresh')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text('Latest Scam News', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: containerHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final it = _items[i];
              final imageUrl = (it.image != null && it.image!.isNotEmpty) ? it.image! : null;

              return GestureDetector(
                onTap: () {
                  if ((it.url ?? '').isNotEmpty) _openLink(it.url);
                },
                child: Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IMAGE (fixed height + placeholder fallback)
                     ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
  child: SizedBox(
    height: 96,
    width: double.infinity,
    child: Image.asset(
      'assets/images/news_placeholder.png',
      fit: BoxFit.cover,
    ),
  ),
),


                      // TITLE ONLY (compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Text(
                          it.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
