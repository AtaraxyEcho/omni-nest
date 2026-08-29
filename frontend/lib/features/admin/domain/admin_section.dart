enum AdminSectionGroup {
  overview,
  operations,
  identity,
  configuration,
  storage,
}

enum AdminSection {
  overview(group: AdminSectionGroup.overview, pathSegment: 'overview'),
  analytics(group: AdminSectionGroup.overview, pathSegment: 'analytics'),
  monitoring(group: AdminSectionGroup.operations, pathSegment: 'monitoring'),
  logs(group: AdminSectionGroup.operations, pathSegment: 'logs'),
  tasks(group: AdminSectionGroup.operations, pathSegment: 'tasks'),
  sessions(group: AdminSectionGroup.operations, pathSegment: 'sessions'),
  users(group: AdminSectionGroup.identity, pathSegment: 'users'),
  roles(group: AdminSectionGroup.identity, pathSegment: 'roles'),
  config(group: AdminSectionGroup.configuration, pathSegment: 'config'),
  storage(group: AdminSectionGroup.storage, pathSegment: 'storage'),
  externalStorage(
    group: AdminSectionGroup.storage,
    pathSegment: 'external-storage',
  );

  const AdminSection({required this.group, required this.pathSegment});

  final AdminSectionGroup group;
  final String pathSegment;

  String get location => '/admin/$pathSegment';

  static AdminSection fromPathSegment(String? segment) {
    for (final section in values) {
      if (section.pathSegment == segment) {
        return section;
      }
    }
    return AdminSection.overview;
  }

  static Map<AdminSectionGroup, List<AdminSection>> get grouped {
    return {
      for (final group in AdminSectionGroup.values)
        group: values
            .where((section) => section.group == group)
            .toList(growable: false),
    };
  }
}
