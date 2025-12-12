// lib/services/news_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:flutter/foundation.dart';

// single source of truth for the data type:
import '../models/news_item.dart' as model;

class NewsService {
  // Base host for turning relative URLs into absolute ones
  static const _base = 'https://www.freemalaysiatoday.com';

  /// Fetch latest articles that match the query "FRAUD".
  /// Returns up to [limit] items (default 3).
 // inside class NewsService

  /// Fetch latest articles that match the query "FRAUD".
  /// Returns up to [limit] items (default 3).
  Future<List<model.NewsItem>> fetchLatest({int limit = 3}) async {
    final url = Uri.parse(
        'https://www.freemalaysiatoday.com/search?term=FRAUD&category=all');

    final headers = {
      // realistic browser UA helps the site return full HTML
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    final resp = await http.get(url, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load news: ${resp.statusCode}');
    }

    final html = utf8.decode(resp.bodyBytes);
    final doc = html_parser.parse(html);

    final List<model.NewsItem> results = [];

    // --- 1) Try JSON-LD ItemList (most robust if present) ---
    try {
      final scripts = doc.querySelectorAll('script[type="application/ld+json"]');
      debugPrint('news: found ${scripts.length} ld+json scripts');

      for (final s in scripts) {
        if (results.length >= limit) break;
        try {
          final dynamic data = json.decode(s.text);
          // normalize: sometimes data is a List or Map
          if (data is List) {
            for (final block in data) {
              if (results.length >= limit) break;
              if (block is Map && block['@type'] == 'ItemList') {
                final list = block['itemListElement'] as List<dynamic>? ?? [];
                for (final entry in list) {
                  if (results.length >= limit) break;
                  final item = (entry is Map && entry['item'] != null) ? entry['item'] : entry;
                  if (item is Map) {
                    final title = item['headline'] ?? item['name'];
                    final link = item['url'] ?? item['@id'];
                    final image = item['image'] is List ? (item['image'] as List).first : item['image'];
                    if (title != null && link != null) {
                      results.add(model.NewsItem(
                        title: title.toString(),
                        url: _absoluteUrl(link.toString()),
                        excerpt: item['description']?.toString(),
                        image: image != null ? _absoluteUrl(image.toString()) : null,
                      ));
                    }
                  }
                }
              }
            }
          } else if (data is Map) {
            if (data['@type'] == 'ItemList' && data['itemListElement'] is List) {
              final list = data['itemListElement'] as List<dynamic>;
              for (final entry in list) {
                if (results.length >= limit) break;
                final item = (entry is Map && entry['item'] != null) ? entry['item'] : entry;
                if (item is Map) {
                  final title = item['headline'] ?? item['name'];
                  final link = item['url'] ?? item['@id'];
                  final image = item['image'] is List ? (item['image'] as List).first : item['image'];
                  if (title != null && link != null) {
                    results.add(model.NewsItem(
                      title: title.toString(),
                      url: _absoluteUrl(link.toString()),
                      excerpt: item['description']?.toString(),
                      image: image != null ? _absoluteUrl(image.toString()) : null,
                    ));
                  }
                }
              }
            }
          }
        } catch (e) {
          // ignore malformed JSON and continue
        }
      }
      debugPrint('news: parsed ${results.length} items from JSON-LD');
    } catch (e) {
      debugPrint('news: json-ld parse error $e');
    }

    // --- 2) Fallback to scraping HTML elements if JSON-LD gave nothing ---
    if (results.isEmpty) {
      debugPrint('news: falling back to HTML scraping');
      final candidates = <Element>[];
      candidates.addAll(doc.querySelectorAll('article'));
      candidates.addAll(doc.querySelectorAll('.td_module_wrap'));
      candidates.addAll(doc.querySelectorAll('.td-block-span6 .td-module-container'));
      candidates.addAll(doc.querySelectorAll('.post'));
      candidates.addAll(doc.querySelectorAll('.entry'));

      final seen = <Element>{};
      final filtered = <Element>[];
      for (final el in candidates) {
        if (!seen.contains(el)) {
          seen.add(el);
          filtered.add(el);
        }
      }

      for (final el in filtered) {
        if (results.length >= limit) break;
        // find title anchor
        final titleEl = el.querySelector('h3 a') ??
            el.querySelector('h2 a') ??
            el.querySelector('.entry-title a') ??
            el.querySelector('.td-module-title a') ??
            el.querySelector('a.title') ??
            el.querySelector('a');

        final href = titleEl?.attributes['href'] ?? titleEl?.attributes['data-href'];
        final titleText = titleEl?.text?.trim();

        if (titleText == null || href == null) continue;

        // image: try <img>, then style background
        String? img;
        final imgEl = el.querySelector('img');
        if (imgEl != null) {
          img = imgEl.attributes['data-src'] ?? imgEl.attributes['src'] ?? imgEl.attributes['data-lazy-src'];
        }
        if ((img == null || img.isEmpty)) {
          final bg = el.querySelector('[style*="background-image"], [style*="background"]');
          if (bg != null) {
            final style = bg.attributes['style'] ?? '';
            final reg = RegExp("url\\([\"']?(.*?)[\"']?\\)");
            final m = reg.firstMatch(style);
            if (m != null) img = m.group(1);
          }
        }

        results.add(model.NewsItem(
          title: titleText,
          url: _absoluteUrl(href),
          excerpt: _extractExcerpt(el),
          image: img != null ? _absoluteUrl(img) : null,
        ));
      }
      debugPrint('news: parsed ${results.length} items from HTML scraping');
    }

    // Final: trim to limit and print for debugging
    final out = results.take(limit).toList();
    for (final it in out) {
      debugPrint('NEWS: ${it.title} | ${it.url} | image=${it.image}');
    }
    return out;
  }



  String? _extractTitle(Element el) {
    final t = el.querySelector('h3 a') ??
        el.querySelector('h2 a') ??
        el.querySelector('.entry-title a') ??
        el.querySelector('.td-module-title a') ??
        el.querySelector('a.title') ??
        el.querySelector('a');
    if (t == null) return null;
    return t.text.trim();
  }

  String? _extractUrl(Element el) {
    final a = el.querySelector('h3 a') ??
        el.querySelector('h2 a') ??
        el.querySelector('.entry-title a') ??
        el.querySelector('.td-module-title a') ??
        el.querySelector('a.title') ??
        el.querySelector('a');
    if (a == null) return null;
    final href = a.attributes['href'] ?? a.attributes['data-href'];
    if (href == null) return null;
    return href.trim();
  }

  String? _extractExcerpt(Element el) {
    final p = el.querySelector('p') ??
        el.querySelector('.excerpt') ??
        el.querySelector('.td-excerpt');
    if (p != null) {
      final t = p.text.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  String? _extractImageFromElement(Element el) {
    // 1) try <img> tags (common)
    final img = el.querySelector('img');
    if (img != null) {
      final src = img.attributes['data-src'] ??
          img.attributes['src'] ??
          img.attributes['data-lazy-src'];
      if (src != null && src.isNotEmpty) return src.trim();
    }

    // 2) try style background-image: url("...") or url('...') or url(...)
    final bg = el.querySelector('[style*="background-image"], [style*="background"]');
    if (bg != null) {
      final style = bg.attributes['style'] ?? '';
      // raw RegExp string is safe here
      final reg = RegExp("url\\([\"']?(.*?)[\"']?\\)");
      final match = reg.firstMatch(style);
      if (match != null) {
        final captured = match.group(1);
        if (captured != null && captured.isNotEmpty) return captured.trim();
      }
    }

    // 3) meta og:image fallback (rare in search snippet but safe)
    final metaImg = el.querySelector('meta[property="og:image"]');
    if (metaImg != null) {
      final src = metaImg.attributes['content'];
      if (src != null && src.isNotEmpty) return src.trim();
    }

    // 4) try figure > img
    final figImg = el.querySelector('figure img');
    if (figImg != null) {
      final src = figImg.attributes['src'] ?? figImg.attributes['data-src'];
      if (src != null && src.isNotEmpty) return src.trim();
    }

    return null;
  }

  String _absoluteUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$_base$url';
    return '$_base/$url';
  }

  // optional small cache / helper if you want later
  static void clearCache() {}
}
