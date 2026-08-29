import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';

final appBackdropSceneControllerProvider =
    NotifierProvider<AppBackdropSceneController, AppBackdropSceneState>(
      AppBackdropSceneController.new,
    );

/// 汇总前景模块背景意图并选择最近激活场景。
class AppBackdropSceneController extends Notifier<AppBackdropSceneState> {
  final Map<String, _OwnedBackdropPolicy> _policies =
      <String, _OwnedBackdropPolicy>{};
  int _sequence = 0;

  @override
  AppBackdropSceneState build() => const AppBackdropSceneState();

  /// 注册或更新前景模块的背景策略。
  ///
  /// [owner] 是前景模块的稳定标识，[policy] 是模块请求的背景策略。
  /// 返回值是本次注册的租约，释放时可用于避免删除同名的新注册。
  int request(String owner, AppBackdropPolicy policy) {
    if (!ref.mounted) {
      return 0;
    }
    final current = _policies[owner];
    if (current?.policy == policy && state.owner == owner) {
      return current!.sequence;
    }
    _sequence++;
    _policies[owner] = _OwnedBackdropPolicy(
      policy: policy,
      sequence: _sequence,
    );
    _resolve();
    return _sequence;
  }

  /// 释放 [owner] 持有的背景策略。
  ///
  /// 指定 [lease] 时仅释放匹配的注册；省略租约时强制释放当前注册。
  void release(String owner, {int? lease}) {
    if (!ref.mounted) {
      return;
    }
    final current = _policies[owner];
    if (current == null || (lease != null && current.sequence != lease)) {
      return;
    }
    _policies.remove(owner);
    _resolve();
  }

  void _resolve() {
    if (_policies.isEmpty) {
      state = const AppBackdropSceneState();
      return;
    }
    final entries = _policies.entries.toList(growable: false)..sort(
      (left, right) => right.value.sequence.compareTo(left.value.sequence),
    );
    final active = entries.first;
    state = AppBackdropSceneState(
      owner: active.key,
      policy: active.value.policy,
    );
  }
}

class _OwnedBackdropPolicy {
  const _OwnedBackdropPolicy({required this.policy, required this.sequence});

  final AppBackdropPolicy policy;
  final int sequence;
}
