import 'package:flutter_test/flutter_test.dart';
import 'package:pengumuman_desa/features/announcement/data/models/announcement_model.dart';

void main() {
  test(
    'Announcement.fromJson parses nullable image and defaults view_count',
    () {
      final data = {
        'id': 'a1',
        'title': 'Tes',
        'content': 'Konten',
        'category': 'umum',
        'image_url': null,
        'status': 'published',
        'created_at': '2026-05-28T10:00:00Z',
        'updated_at': '2026-05-28T11:00:00Z',
      };

      final model = Announcement.fromJson(data);
      expect(model.id, 'a1');
      expect(model.imageUrl, isNull);
      expect(model.viewCount, 0);
    },
  );

  test('Announcement.fromJson keeps provided view_count', () {
    final data = {
      'id': 'a2',
      'title': 'Tes 2',
      'content': 'Konten 2',
      'category': 'kesehatan',
      'image_url': 'https://example.com/test.jpg',
      'status': 'draft',
      'created_at': '2026-05-28T10:00:00Z',
      'updated_at': '2026-05-28T11:00:00Z',
      'view_count': 27,
    };

    final model = Announcement.fromJson(data);
    expect(model.imageUrl, 'https://example.com/test.jpg');
    expect(model.viewCount, 27);
  });
}
