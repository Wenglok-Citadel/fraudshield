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
      debugPrint('NEWS-DEBUG: fetched ${list.length} items');
      for (var i = 0; i < list.length; i++) {
        final it = list[i];
        debugPrint('NEWS-DEBUG[$i]: title="${it.title}" url="${it.url}" image="${it.image}"');
      }
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e, st) {
      debugPrint('NEWS-DEBUG: fetch error: $e\n$st');
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator()),
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
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final it = _items[i];
              return GestureDetector(
                onTap: () async {
                  final link = it.url;
                  if (link == null || link.isEmpty) return;
                  final uri = Uri.tryParse(link);
                  if (uri == null) return;
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open article')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open article')));
                  }
                },
                child: Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // image
                      (it.image != null && it.image!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                it.image!,
                                width: double.infinity,
                                height: 100,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(height: 100, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2));
                                },
                                errorBuilder: (_, __, ___) => Container(height: 100, color: Colors.grey[200]),
                              ),
                            )
                          : Container(height: 100, color: Colors.grey[200]),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(it.excerpt ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
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
