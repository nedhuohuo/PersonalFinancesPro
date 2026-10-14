import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverPage(
      title: '设置',
      slivers: [
        paddedSliver([
          const InfoCard(
            title: '数据保存在本机',
            body: '账本保存到已排除系统自动备份的本机 SQLite；启动检查失败会阻止进入账本。',
          ),
          _CatalogButton(title: '店铺', route: '/settings/catalog/shops'),
          _CatalogButton(title: '账户', route: '/settings/catalog/accounts'),
          _CatalogButton(title: '往来方', route: '/settings/catalog/parties'),
          _CatalogButton(title: '分类', route: '/settings/catalog/categories'),
          _CatalogButton(title: '渠道', route: '/settings/catalog/channels'),
          const InfoCard(title: 'AI记账', body: 'AI 服务尚未连接；不会在设置页收集或保存服务密钥。'),
          const InfoCard(
            title: '安全与数据',
            body:
                '排除自动备份不等于备份；完整备份与恢复尚未实现。卸载或设备损坏可能导致未备份账本丢失。导入、导出和 CSV 在后续任务启用。',
          ),
          const InfoCard(title: '显示', body: '跟随系统明暗模式和文字大小。'),
          const InfoCard(title: '隐私', body: '没有网络服务接入时，页面不会上传或同步任何账目。'),
          const InfoCard(title: '关于项目', body: 'Personal Finances Pro 网店账本基础版。'),
          const InfoCard(
            key: ValueKey('settings-version-row'),
            title: '版本 0.1.0',
            body: 'Flutter 本地账本基础阶段。',
          ),
        ]),
      ],
    );
  }
}

class _CatalogButton extends StatelessWidget {
  const _CatalogButton({required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color: appColor(
        context,
        CupertinoColors.secondarySystemGroupedBackground,
      ),
      onPressed: () => context.push(route),
      child: Align(alignment: Alignment.centerLeft, child: Text('基础资料：$title')),
    );
  }
}
