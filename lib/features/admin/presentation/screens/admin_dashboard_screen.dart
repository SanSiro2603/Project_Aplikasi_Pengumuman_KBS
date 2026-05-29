import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/auth/admin_access.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../announcement/data/models/announcement_model.dart';
import '../../../announcement/presentation/providers/announcement_provider.dart';
import '../../../guest/presentation/widgets/zoomable_image_viewer.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout Admin'),
          content: const Text('Yakin ingin keluar dari panel admin?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;

    context.go('/home');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Berhasil logout.')));
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Announcement announcement,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Pengumuman'),
          content: Text('Hapus "${announcement.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD64545),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    if (!AdminAccess.isAdmin()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akses ditolak. Hanya admin.')),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('announcements')
          .delete()
          .eq('id', announcement.id);
      ref.invalidate(adminAnnouncementsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengumuman berhasil dihapus.')),
      );
    } catch (e) {
      await AppLogger.error(
        'admin_dashboard.delete_announcement',
        e,
        context: {'announcement_id': announcement.id},
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(adminAnnouncementsProvider);
    final publishedCount = announcementsAsync.maybeWhen(
      data: (items) => items.where((item) => item.status == 'published').length,
      orElse: () => 0,
    );
    final draftCount = announcementsAsync.maybeWhen(
      data: (items) => items.where((item) => item.status == 'draft').length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F4),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: const Color.fromARGB(255, 249, 249, 247),
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF162033),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF162033),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(HugeIcons.strokeRoundedLogout02),
            tooltip: 'Logout',
            onPressed: () => _confirmAndLogout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/form'),
        backgroundColor: const Color(0xFF1F9D57),
        foregroundColor: Colors.white,
        icon: const Icon(HugeIcons.strokeRoundedAddCircle),
        label: const Text('Buat Pengumuman'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF187E4E), Color(0xFF1FA862)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1FA862).withValues(alpha: 0.27),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0x33FFFFFF),
                    child: Icon(
                      HugeIcons.strokeRoundedDashboardSquare02,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panel Kelola Pengumuman',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Published: $publishedCount - Draft: $draftCount',
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: announcementsAsync.when(
              data: (announcements) {
                if (announcements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          HugeIcons.strokeRoundedNote04,
                          size: 56,
                          color: Color(0xFF7E8A97),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada pengumuman.',
                          style: TextStyle(
                            color: Color(0xFF61707E),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    return _AdminAnnouncementCard(
                      announcement: announcements[index],
                      onEdit: () => context.go(
                        '/admin/form?id=${announcements[index].id}',
                      ),
                      onDelete: () =>
                          _confirmAndDelete(context, ref, announcements[index]),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go('/home');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(HugeIcons.strokeRoundedHome01),
            label: 'Home Warga',
          ),
          NavigationDestination(
            icon: Icon(HugeIcons.strokeRoundedDashboardSquare02),
            label: 'Kelola',
          ),
        ],
      ),
    );
  }
}

class _AdminAnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminAnnouncementCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat(
      'dd MMM yyyy',
    ).format(announcement.updatedAt);
    final isPublished = announcement.status == 'published';
    final statusColor = isPublished
        ? const Color(0xFF178A52)
        : const Color(0xFF9A6A12);
    final statusBg = isPublished
        ? const Color(0xFFDCF5E7)
        : const Color(0xFFFFF0D9);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8AB79F).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImagePreview(imageUrl: announcement.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isPublished ? 'PUBLISHED' : 'DRAFT',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2232),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    announcement.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF677483),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        HugeIcons.strokeRoundedCalendar01,
                        size: 15,
                        color: Color(0xFF6D7A88),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormatted,
                        style: const TextStyle(
                          color: Color(0xFF6D7A88),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onEdit,
                        tooltip: 'Edit',
                        icon: const Icon(
                          HugeIcons.strokeRoundedEdit01,
                          color: Color(0xFF1F8B55),
                        ),
                      ),
                      IconButton(
                        onPressed: onDelete,
                        tooltip: 'Hapus',
                        icon: const Icon(
                          HugeIcons.strokeRoundedDelete02,
                          color: Color(0xFFD24A4A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String? imageUrl;

  const _ImagePreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: !hasImage
          ? null
          : () => ZoomableImageViewer.open(context, imageUrl!),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 86,
              height: 86,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          _noImagePlaceholder(),
                    )
                  : _noImagePlaceholder(),
            ),
          ),
          if (hasImage)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  HugeIcons.strokeRoundedView,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noImagePlaceholder() {
    return Container(
      color: const Color(0xFFEAF0ED),
      child: const Icon(
        HugeIcons.strokeRoundedImage01,
        color: Color(0xFF8C98A5),
        size: 24,
      ),
    );
  }
}
