import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/announcement_model.dart';
import '../../data/repositories/announcement_repository.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return SupabaseAnnouncementRepository();
});

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final repository = ref.watch(announcementRepositoryProvider);
  return repository.getAnnouncementsStream();
});

final adminAnnouncementsProvider = StreamProvider<List<Announcement>>((ref) {
  final repository = ref.watch(announcementRepositoryProvider);
  return repository.getAdminAnnouncementsStream();
});
