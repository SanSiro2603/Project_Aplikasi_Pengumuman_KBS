import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AdminFormScreen extends StatefulWidget {
  final String? id;
  const AdminFormScreen({super.key, this.id});

  @override
  State<AdminFormScreen> createState() => _AdminFormScreenState();
}

class _AdminFormScreenState extends State<AdminFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _status = 'draft';
  String _category = 'umum';
  XFile? _selectedImage;
  String? _existingImageUrl;
  String? _initialStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('announcements')
          .select()
          .eq('id', widget.id!)
          .single();
      setState(() {
        _titleController.text = data['title'];
        _contentController.text = data['content'];
        _category = data['category'];
        _status = data['status'];
        _initialStatus = data['status'] as String?;
        _existingImageUrl = data['image_url'] as String?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndCompressImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final compressedFile = await _compressImageSafely(pickedFile);
      if (!mounted) return;
      setState(() => _selectedImage = compressedFile ?? pickedFile);

      if (compressedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gambar dipakai tanpa kompres karena format tidak didukung kompresor.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Compress error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<XFile?> _compressImageSafely(XFile originalFile) async {
    final baseName = p.basenameWithoutExtension(originalFile.path);
    final targetPath =
        '${p.dirname(originalFile.path)}/compressed_${baseName}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return FlutterImageCompress.compressAndGetFile(
      originalFile.path,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 720,
      format: CompressFormat.jpeg,
      keepExif: true,
      autoCorrectionAngle: true,
    );
  }

  Future<void> _saveAnnouncement() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Isi judul dan konten')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        var ext = p.extension(_selectedImage!.path).toLowerCase();
        if (ext.isEmpty) ext = '.jpg';
        final fileName = '${const Uuid().v4()}$ext';
        final filePath = 'images/$fileName';

        await Supabase.instance.client.storage
            .from('announcements')
            .upload(filePath, File(_selectedImage!.path));

        imageUrl = Supabase.instance.client.storage
            .from('announcements')
            .getPublicUrl(filePath);
      }

      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _category,
        'status': _status,
      };
      if (imageUrl != null) {
        payload['image_url'] = imageUrl;
      }

      String announcementId = widget.id ?? '';
      String announcementTitle = _titleController.text.trim();
      String announcementCategory = _category;

      if (widget.id == null) {
        final inserted = await Supabase.instance.client
            .from('announcements')
            .insert(payload)
            .select('id,title,category,status')
            .single();
        announcementId = inserted['id'] as String;
        announcementTitle = inserted['title'] as String;
        announcementCategory = inserted['category'] as String;
      } else {
        payload['updated_at'] = DateTime.now().toIso8601String();
        final updated = await Supabase.instance.client
            .from('announcements')
            .update(payload)
            .eq('id', widget.id!)
            .select('id,title,category,status');
        if (updated.isNotEmpty) {
          final first = updated.first;
          announcementId = first['id'] as String;
          announcementTitle = first['title'] as String;
          announcementCategory = first['category'] as String;
        }
      }

      final shouldNotify =
          _status == 'published' &&
          (widget.id == null || _initialStatus != 'published');
      if (shouldNotify) {
        await _triggerPublishNotification(
          id: announcementId,
          title: announcementTitle,
          category: announcementCategory,
        );
      }

      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerPublishNotification({
    required String id,
    required String title,
    required String category,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'notify_warga',
        body: {
          'record': {
            'id': id,
            'title': title,
            'category': category,
            'status': 'published',
          },
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengumuman tersimpan, tapi push notifikasi gagal: $e'),
        ),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF33445A),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF5F6D7D)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB7C5BD), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB7C5BD), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E9E58), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD14D4D), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F4),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: const Color.fromARGB(255, 249, 249, 247),
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF162033),
        title: Text(widget.id == null ? 'Buat Pengumuman' : 'Edit Pengumuman'),
        leading: IconButton(
          icon: const Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: Color(0xFF162033),
          ),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8CB7A0).withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: _decoration(
                          'Judul Pengumuman *',
                          HugeIcons.strokeRoundedNoteEdit,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: _decoration(
                          'Kategori *',
                          HugeIcons.strokeRoundedListView,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'umum', child: Text('Umum')),
                          DropdownMenuItem(
                            value: 'kesehatan',
                            child: Text('Kesehatan'),
                          ),
                          DropdownMenuItem(
                            value: 'infrastruktur',
                            child: Text('Infrastruktur'),
                          ),
                          DropdownMenuItem(
                            value: 'keuangan',
                            child: Text('Keuangan'),
                          ),
                          DropdownMenuItem(
                            value: 'acara',
                            child: Text('Acara'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _contentController,
                        maxLines: 6,
                        decoration: _decoration(
                          'Isi Pengumuman *',
                          HugeIcons.strokeRoundedFileEdit,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickAndCompressImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD7E2DC)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF8CB7A0,
                          ).withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gambar Pengumuman',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 190,
                            child: _selectedImage != null
                                ? Image.file(
                                    File(_selectedImage!.path),
                                    fit: BoxFit.cover,
                                  )
                                : (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: _existingImageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        _emptyImageState(),
                                  )
                                : _emptyImageState(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(
                              HugeIcons.strokeRoundedImageUpload01,
                              size: 16,
                              color: Color(0xFF607285),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tap untuk ganti gambar (auto-compress aktif)',
                              style: TextStyle(
                                color: Color(0xFF607285),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8CB7A0).withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Draft'),
                            selected: _status == 'draft',
                            onSelected: (_) =>
                                setState(() => _status = 'draft'),
                          ),
                          ChoiceChip(
                            label: const Text('Published'),
                            selected: _status == 'published',
                            onSelected: (_) =>
                                setState(() => _status = 'published'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E9E58),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saveAnnouncement,
                    icon: const Icon(HugeIcons.strokeRoundedFileUpload),
                    label: const Text(
                      'Simpan Pengumuman',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _emptyImageState() {
    return Container(
      color: const Color(0xFFE9F0EC),
      child: const Center(
        child: Icon(
          HugeIcons.strokeRoundedImage01,
          color: Color(0xFF7E8F9F),
          size: 34,
        ),
      ),
    );
  }
}
