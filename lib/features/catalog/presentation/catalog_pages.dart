import 'package:flutter/cupertino.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/catalog/presentation/catalog_view_model.dart';
import 'package:provider/provider.dart';

CatalogKind catalogKindFromPath(String path) => switch (path) {
  'shops' => CatalogKind.shops,
  'accounts' => CatalogKind.accounts,
  'parties' => CatalogKind.parties,
  'categories' => CatalogKind.categories,
  'channels' => CatalogKind.channels,
  _ => throw ArgumentError('unknown catalog kind: $path'),
};

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.kind, this.viewModelBuilder});

  final CatalogKind kind;
  final CatalogViewModel Function(BuildContext context)? viewModelBuilder;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final CatalogViewModel _viewModel =
      widget.viewModelBuilder?.call(context) ??
      CatalogViewModel(catalogRepository: context.read<CatalogRepository>());

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_viewModel.reload);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder:
          (context, _) => PopScope(
            canPop: !_viewModel.isSaving,
            child: CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                middle: Text(catalogKindTitle(widget.kind)),
                transitionBetweenRoutes: false,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed:
                      _viewModel.canMutate ? () => _create(context) : null,
                  child: const Text('新增'),
                ),
              ),
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(appPadding),
                  children: [
                    if (_viewModel.isLoading)
                      const InfoCard(title: '正在读取', body: '正在加载基础资料。'),
                    if (_viewModel.errorMessage != null)
                      InfoCard(title: '提示', body: _viewModel.errorMessage!),
                    CupertinoButton(
                      onPressed:
                          _viewModel.isSaving || _viewModel.isLoading
                              ? null
                              : _viewModel.reload,
                      child: const Text('刷新'),
                    ),
                    for (final item in _items())
                      _CatalogRow(
                        item: item,
                        enabled: _viewModel.canMutate,
                        onRename: _rename,
                        onDeactivate: _deactivate,
                      ),
                    if (_items().isEmpty)
                      const InfoCard(title: '暂无资料', body: '点击右上角新增。'),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  List<_CatalogItem> _items() => switch (widget.kind) {
    CatalogKind.shops => [
      for (final item in _viewModel.shops)
        _CatalogItem(item.id, item.name, item.isActive, ''),
    ],
    CatalogKind.accounts => [
      for (final item in _viewModel.accounts)
        _CatalogItem(item.id, item.name, item.isActive, ''),
    ],
    CatalogKind.parties => [
      for (final item in _viewModel.parties)
        _CatalogItem(
          item.id,
          item.name,
          item.isActive,
          _partyKindLabel(item.kind),
        ),
    ],
    CatalogKind.categories => [
      for (final item in _viewModel.categories)
        _CatalogItem(
          item.id,
          item.name,
          item.isActive,
          '${item.direction == CashDirection.income ? '收入' : '支出'} · ${item.isSystem ? '系统' : '自建'}',
        ),
    ],
    CatalogKind.channels => [
      for (final item in _viewModel.channels)
        _CatalogItem(item.id, item.name, item.isActive, ''),
    ],
  };

  Future<void> _create(BuildContext context) async {
    if (!_viewModel.canMutate) return;
    final extra = await _pickExtra(context);
    if (extra == null || !context.mounted || !_viewModel.canMutate) return;
    await _askName(
      context,
      '新增${catalogKindTitle(widget.kind)}',
      viewModel: _viewModel,
      onSubmit:
          (name) => switch (widget.kind) {
            CatalogKind.shops => _viewModel.createShop(name),
            CatalogKind.accounts => _viewModel.createAccount(name),
            CatalogKind.parties => _viewModel.createParty(
              name,
              extra as PartyKind,
            ),
            CatalogKind.categories => _viewModel.createCategory(
              name,
              extra as CashDirection,
            ),
            CatalogKind.channels => _viewModel.createChannel(name),
          },
    );
  }

  Future<void> _rename(_CatalogItem item) async {
    if (!_viewModel.canMutate) return;
    await _askName(
      context,
      '重命名',
      initial: item.name,
      viewModel: _viewModel,
      onSubmit:
          (name) => switch (widget.kind) {
            CatalogKind.shops => _viewModel.renameShop(item.id, name),
            CatalogKind.accounts => _viewModel.renameAccount(item.id, name),
            CatalogKind.parties => _viewModel.renameParty(item.id, name),
            CatalogKind.categories => _viewModel.renameCategory(item.id, name),
            CatalogKind.channels => _viewModel.renameChannel(item.id, name),
          },
    );
  }

  Future<void> _deactivate(_CatalogItem item) async {
    if (!item.isActive || !_viewModel.canMutate) return;
    await switch (widget.kind) {
      CatalogKind.shops => _viewModel.deactivateShop(item.id),
      CatalogKind.accounts => _viewModel.deactivateAccount(item.id),
      CatalogKind.parties => _viewModel.deactivateParty(item.id),
      CatalogKind.categories => _viewModel.deactivateCategory(item.id),
      CatalogKind.channels => _viewModel.deactivateChannel(item.id),
    };
  }

  Future<Object?> _pickExtra(BuildContext context) async {
    if (widget.kind == CatalogKind.parties) {
      return _pick<PartyKind>(
        context,
        title: '往来方类型',
        entries: {
          for (final kind in PartyKind.values) kind: _partyKindLabel(kind),
        },
      );
    }
    if (widget.kind == CatalogKind.categories) {
      return _pick<CashDirection>(
        context,
        title: '分类方向',
        entries: const {
          CashDirection.expense: '支出',
          CashDirection.income: '收入',
        },
      );
    }
    return true;
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.item,
    required this.enabled,
    required this.onRename,
    required this.onDeactivate,
  });

  final _CatalogItem item;
  final bool enabled;
  final ValueChanged<_CatalogItem> onRename;
  final ValueChanged<_CatalogItem> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        title: '${item.name}${item.isActive ? '' : '（已停用）'}',
        body: [
          if (item.detail.isNotEmpty) item.detail,
          'ID ${item.id}',
        ].join(' · '),
        child: Row(
          children: [
            CupertinoButton(
              onPressed: enabled ? () => onRename(item) : null,
              child: const Text('重命名'),
            ),
            CupertinoButton(
              onPressed:
                  enabled && item.isActive ? () => onDeactivate(item) : null,
              child: const Text('停用'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CatalogItem {
  const _CatalogItem(this.id, this.name, this.isActive, this.detail);
  final int id;
  final String name;
  final bool isActive;
  final String detail;
}

Future<void> _askName(
  BuildContext context,
  String title, {
  String initial = '',
  required CatalogViewModel viewModel,
  required Future<bool> Function(String) onSubmit,
}) => showCupertinoDialog<void>(
  context: context,
  builder:
      (_) => _CatalogNameDialog(
        title: title,
        initial: initial,
        viewModel: viewModel,
        onSubmit: onSubmit,
      ),
);

class _CatalogNameDialog extends StatefulWidget {
  const _CatalogNameDialog({
    required this.title,
    required this.initial,
    required this.viewModel,
    required this.onSubmit,
  });
  final String title;
  final String initial;
  final CatalogViewModel viewModel;
  final Future<bool> Function(String) onSubmit;

  @override
  State<_CatalogNameDialog> createState() => _CatalogNameDialogState();
}

class _CatalogNameDialogState extends State<_CatalogNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder:
        (context, _) => PopScope(
          canPop: !widget.viewModel.isSaving,
          child: CupertinoAlertDialog(
            title: Text(widget.title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  CupertinoTextField(controller: _controller),
                  if (widget.viewModel.errorMessage != null)
                    Text(widget.viewModel.errorMessage!),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed:
                    widget.viewModel.isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed:
                    widget.viewModel.canMutate
                        ? () async {
                          final committed = await widget.onSubmit(
                            _controller.text,
                          );
                          if (committed && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                        : null,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
  );
}

Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> entries,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder:
        (context) => CupertinoActionSheet(
          title: Text(title),
          actions: [
            for (final entry in entries.entries)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(entry.key),
                child: Text(entry.value),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ),
  );
}

String _partyKindLabel(PartyKind kind) => switch (kind) {
  PartyKind.supplier => '厂家',
  PartyKind.buyer => '买家',
  PartyKind.courier => '快递',
  PartyKind.other => '其他',
};
