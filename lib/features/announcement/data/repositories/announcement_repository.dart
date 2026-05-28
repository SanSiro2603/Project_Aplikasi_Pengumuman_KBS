import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement_model.dart';

abstract class AnnouncementRepository {
  Future<List<Announcement>> getAnnouncements();
  Stream<List<Announcement>> getAnnouncementsStream();
  Stream<List<Announcement>> getAdminAnnouncementsStream();
}

class SupabaseAnnouncementRepository implements AnnouncementRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<Announcement>> getAnnouncements() async {
    final response = await _client
        .from('announcements')
        .select()
        .eq('status', 'published')
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => Announcement.fromJson(json)).toList();
  }

  @override
  Stream<List<Announcement>> getAnnouncementsStream() {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => Announcement.fromJson(json)).toList());
  }

  @override
  Stream<List<Announcement>> getAdminAnnouncementsStream() {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => Announcement.fromJson(json)).toList());
  }
}
