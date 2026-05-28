class Announcement {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int viewCount;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.viewCount = 0,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      category: json['category'],
      imageUrl: json['image_url'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      viewCount: json['view_count'] ?? 0,
    );
  }
}
