import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../../core/update/app_update_service.dart';
import '../../../announcement/data/models/announcement_model.dart';
import '../../../announcement/presentation/providers/announcement_provider.dart';
import '../widgets/announcement_card.dart';
import '../widgets/shimmer_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedQuery = '';
  String _selectedCategory = 'semua';
  DateTime? _selectedDate;

  static const List<_CategoryItem> _categories = [
    _CategoryItem('semua', 'Semua', HugeIcons.strokeRoundedListView),
    _CategoryItem('umum', 'Umum', HugeIcons.strokeRoundedHome01),
    _CategoryItem('kesehatan', 'Kesehatan', HugeIcons.strokeRoundedNote04),
    _CategoryItem(
      'infrastruktur',
      'Infrastruktur',
      HugeIcons.strokeRoundedDashboardSquare02,
    ),
    _CategoryItem('keuangan', 'Keuangan', HugeIcons.strokeRoundedMail01),
    _CategoryItem('acara', 'Acara', HugeIcons.strokeRoundedCalendar01),
  ];

  List<_CategoryItem> get _notifCategories =>
      _categories.where((item) => item.key != 'semua').toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHomeSession();
    });
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeHomeSession() async {
    await _promptNotificationAndSoundConsent();
    if (!mounted) return;
    await AppUpdateService.instance.checkAndPrompt(context);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _debouncedQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _pickDateFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  List<Announcement> _applyFilters(List<Announcement> announcements) {
    var filtered = announcements;

    if (_selectedCategory != 'semua') {
      filtered = filtered
          .where((item) => item.category.toLowerCase() == _selectedCategory)
          .toList();
    }

    if (_selectedDate != null) {
      filtered = filtered
          .where(
            (item) => _isSameDate(item.createdAt.toLocal(), _selectedDate!),
          )
          .toList();
    }

    if (_debouncedQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final title = item.title.toLowerCase();
        final content = item.content.toLowerCase();
        final category = item.category.toLowerCase();
        return title.contains(_debouncedQuery) ||
            content.contains(_debouncedQuery) ||
            category.contains(_debouncedQuery);
      }).toList();
    }

    return filtered;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _promptNotificationAndSoundConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('notif_prompt_done') ?? false;
    if (hasPrompted || !mounted) return;

    var allowNotification = true;
    var allowSound = true;

    final result = await showDialog<Map<String, bool>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Izin Notifikasi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Apakah Anda mengizinkan notifikasi untuk pengumuman baru desa?',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: allowNotification,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Izinkan Notifikasi'),
                    onChanged: (value) {
                      setDialogState(() => allowNotification = value);
                      if (!value) setDialogState(() => allowSound = false);
                    },
                  ),
                  SwitchListTile(
                    value: allowSound,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan Nada Dering'),
                    onChanged: allowNotification
                        ? (value) => setDialogState(() => allowSound = value)
                        : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop({'notif': false, 'sound': false});
                  },
                  child: const Text('Nanti'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop({
                      'notif': allowNotification,
                      'sound': allowNotification && allowSound,
                    });
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await prefs.setBool('notif_prompt_done', true);
    await prefs.setBool('notif_allowed', result['notif'] ?? false);
    await prefs.setBool('notif_sound_allowed', result['sound'] ?? false);
    await prefs.setBool('notif_sound_mode_per_category', false);
    await prefs.setBool('notif_sound_single_enabled', result['sound'] ?? false);
    for (final category in _notifCategories) {
      await prefs.setBool(
        'notif_sound_category_${category.key}',
        result['sound'] ?? false,
      );
    }

    if (!mounted) return;

    if (result['notif'] == true) {
      final granted =
          await NotificationService.requestPermissionAndRegisterToken();
      if (!mounted) return;

      if (granted) {
        AppFeedback.success(
          context,
          'Notifikasi aktif. Anda akan menerima pengumuman baru.',
        );
      } else {
        AppFeedback.error(context, 'Izin notifikasi ditolak oleh sistem.');
      }
    } else {
      await NotificationService.syncSettingsFromLocal();
    }
  }

  Future<void> _openNotificationSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();

    bool notifAllowed = prefs.getBool('notif_allowed') ?? false;
    bool modePerCategory =
        prefs.getBool('notif_sound_mode_per_category') ?? false;
    bool singleSoundEnabled =
        prefs.getBool('notif_sound_single_enabled') ??
        (prefs.getBool('notif_sound_allowed') ?? false);
    final perCategorySound = <String, bool>{
      for (final category in _notifCategories)
        category.key:
            prefs.getBool('notif_sound_category_${category.key}') ??
            singleSoundEnabled,
    };

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengaturan Notifikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: notifAllowed,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktifkan Notifikasi'),
                        subtitle: const Text(
                          'Terima notifikasi saat pengumuman baru dipublikasikan.',
                        ),
                        onChanged: (value) {
                          setSheetState(() => notifAllowed = value);
                        },
                      ),
                      const Divider(height: 18),
                      SwitchListTile(
                        value: modePerCategory,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Set suara per kategori'),
                        subtitle: const Text(
                          'Jika aktif, Anda bisa mengatur suara untuk tiap kategori.',
                        ),
                        onChanged: notifAllowed
                            ? (value) {
                                setSheetState(() => modePerCategory = value);
                              }
                            : null,
                      ),
                      if (!modePerCategory)
                        SwitchListTile(
                          value: singleSoundEnabled,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Nada dering default (semua kategori)',
                          ),
                          onChanged: notifAllowed
                              ? (value) {
                                  setSheetState(
                                    () => singleSoundEnabled = value,
                                  );
                                }
                              : null,
                        ),
                      if (modePerCategory)
                        ..._notifCategories.map((category) {
                          final current =
                              perCategorySound[category.key] ??
                              singleSoundEnabled;
                          return SwitchListTile(
                            value: current,
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(category.icon),
                            title: Text('Nada ${category.label}'),
                            onChanged: notifAllowed
                                ? (value) {
                                    setSheetState(() {
                                      perCategorySound[category.key] = value;
                                    });
                                  }
                                : null,
                          );
                        }),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await prefs.setBool('notif_prompt_done', true);
                            await prefs.setBool('notif_allowed', notifAllowed);
                            await prefs.setBool(
                              'notif_sound_mode_per_category',
                              modePerCategory,
                            );
                            await prefs.setBool(
                              'notif_sound_single_enabled',
                              singleSoundEnabled,
                            );
                            for (final category in _notifCategories) {
                              await prefs.setBool(
                                'notif_sound_category_${category.key}',
                                perCategorySound[category.key] ?? false,
                              );
                            }

                            final hasAnySound = modePerCategory
                                ? perCategorySound.values.any(
                                    (enabled) => enabled,
                                  )
                                : singleSoundEnabled;
                            await prefs.setBool(
                              'notif_sound_allowed',
                              notifAllowed && hasAnySound,
                            );

                            if (notifAllowed) {
                              final granted =
                                  await NotificationService.requestPermissionAndRegisterToken();
                              if (!context.mounted) return;
                              if (!granted) {
                                await prefs.setBool('notif_allowed', false);
                                await prefs.setBool(
                                  'notif_sound_allowed',
                                  false,
                                );
                                if (!context.mounted) return;
                                AppFeedback.error(
                                  context,
                                  'Izin notifikasi ditolak oleh sistem.',
                                );
                              }
                            } else {
                              await NotificationService.syncSettingsFromLocal();
                            }

                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Simpan Pengaturan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desa Maju Jaya'),
        actions: [
          IconButton(
            icon: const Icon(HugeIcons.strokeRoundedDashboardSquare02),
            tooltip: 'Panel Admin',
            onPressed: () => context.push('/admin'),
          ),
          IconButton(
            icon: const Icon(HugeIcons.strokeRoundedNotification01),
            onPressed: _openNotificationSoundSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari pengumuman...',
                      prefixIcon: const Icon(HugeIcons.strokeRoundedSearch01),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _debouncedQuery = '');
                              },
                              icon: const Icon(HugeIcons.strokeRoundedDelete02),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: _pickDateFilter,
                  icon: const Icon(HugeIcons.strokeRoundedCalendar01),
                  label: const Text('Tanggal'),
                ),
              ],
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(
                    HugeIcons.strokeRoundedCalendar01,
                    size: 16,
                  ),
                  label: Text(
                    'Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                  ),
                  onDeleted: () => setState(() => _selectedDate = null),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: _categories.map((item) {
                final isSelected = _selectedCategory == item.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    showCheckmark: false,
                    avatar: Icon(item.icon, size: 18),
                    label: Text(item.label),
                    selected: isSelected,
                    selectedColor: const Color(
                      0xFF1E9E58,
                    ).withValues(alpha: 0.18),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF1E9E58)
                          : const Color(0xFFD6E0DA),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF1A7F49)
                          : const Color(0xFF4E5D6F),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = item.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: announcementsAsync.when(
              data: (announcements) {
                final filteredAnnouncements = _applyFilters(announcements);

                if (filteredAnnouncements.isEmpty) {
                  return Center(
                    child: FadeInUp(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.network(
                            'https://lottie.host/96fbaf04-9ed3-45ab-8dd6-9e63eefcd7b9/A9Zl51F5yT.json',
                            width: 200,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  HugeIcons.strokeRoundedSearchList01,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            announcements.isEmpty
                                ? 'Belum ada pengumuman'
                                : 'Tidak ada hasil sesuai filter',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LiquidPullToRefresh(
                  onRefresh: () async {
                    ref.invalidate(announcementsProvider);
                  },
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Colors.white,
                  showChildOpacityTransition: false,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredAnnouncements.length,
                    itemBuilder: (context, index) {
                      final announcement = filteredAnnouncements[index];
                      return FadeInUp(
                        delay: Duration(milliseconds: index * 100),
                        duration: const Duration(milliseconds: 500),
                        child: AnnouncementCard(
                          announcement: announcement,
                          onTap: () {
                            context.push('/detail/${announcement.id}');
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (context, index) => const ShimmerCard(),
              ),
              error: (error, stackTrace) =>
                  Center(child: Text('Gagal memuat data: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final String key;
  final String label;
  final IconData icon;

  const _CategoryItem(this.key, this.label, this.icon);
}
