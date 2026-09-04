import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_relation_view.dart';

PhotoRelationGraph _relation({
  required List<PhotoRelationNode> nodes,
  required List<PhotoRelationEdge> edges,
}) {
  return PhotoRelationGraph(nodes: nodes, edges: edges, truncated: false);
}

void main() {
  test('relationEntitiesForDimension 按维度过滤、按权重排序并富化相册封面', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 10,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.time,
          key: '2026-08',
          label: null,
          weight: 6,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.person,
          key: 'person-1',
          label: 'Alice',
          weight: 30,
        ),
      ],
      edges: const [],
    );

    final entities = relationEntitiesForDimension(
      relation: relation,
      dimension: PhotoRelationNodeType.album,
    );

    expect(entities, hasLength(1));
    expect(entities.single.label, 'Japan');
  });

  test('relationEntitiesForDimension 时间节点标签回退到 key 并支持截断', () {
    final relation = _relation(
      nodes: [
        for (var index = 0; index < 5; index++)
          PhotoRelationNode(
            type: PhotoRelationNodeType.time,
            key: '2026-0${index + 1}',
            label: null,
            weight: 5 - index,
          ),
      ],
      edges: const [],
    );

    final entities = relationEntitiesForDimension(
      relation: relation,
      dimension: PhotoRelationNodeType.time,
      limit: 3,
    );

    expect(entities, hasLength(3));
    expect(entities.first.label, '2026-01');
    expect(entities.first.weight, 5);
    expect(
      relationEntitiesOverflow(
        relation: relation,
        dimension: PhotoRelationNodeType.time,
        limit: 3,
      ),
      2,
    );
  });

  test('relatedEntities 返回与选中实体相连的实体并按共现强度排序', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 20,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.time,
          key: '2026-08',
          label: null,
          weight: 12,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.location,
          key: '青岛',
          label: null,
          weight: 7,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.person,
          key: 'person-1',
          label: 'Alice',
          weight: 40,
        ),
      ],
      edges: [
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.location,
          targetKey: '青岛',
          weight: 9,
        ),
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.time,
          targetKey: '2026-08',
          weight: 14,
        ),
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.person,
          targetKey: 'person-1',
          weight: 33,
        ),
      ],
    );
    final selected =
        relationEntitiesForDimension(
          relation: relation,
          dimension: PhotoRelationNodeType.album,
        ).single;

    final related = relatedEntities(relation: relation, selected: selected);

    expect(related, hasLength(2));
    expect(related.first.label, '2026-08');
    expect(related.last.label, '青岛');
  });

  test('relatedEntities 忽略与选中实体无关的边', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 20,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.time,
          key: '2026-08',
          label: null,
          weight: 12,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.location,
          key: '青岛',
          label: null,
          weight: 7,
        ),
      ],
      edges: [
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.time,
          sourceKey: '2026-08',
          targetType: PhotoRelationNodeType.location,
          targetKey: '青岛',
          weight: 5,
        ),
      ],
    );
    final selected =
        relationEntitiesForDimension(
          relation: relation,
          dimension: PhotoRelationNodeType.album,
        ).single;

    expect(relatedEntities(relation: relation, selected: selected), isEmpty);
  });
}
