/// 人脸聚类模型
class PhotoFaceCluster {
  const PhotoFaceCluster({
    required this.id,
    this.name,
    required this.faceCount,
    this.coverPhotoUrl,
  });

  final String id;
  final String? name;
  final int faceCount;
  final String? coverPhotoUrl;

  factory PhotoFaceCluster.fromJson(Map<String, dynamic> json) {
    return PhotoFaceCluster(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      faceCount: (json['faceCount'] as num?)?.toInt() ?? 0,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
    );
  }
}
