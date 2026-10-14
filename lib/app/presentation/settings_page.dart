import 'package:flutter/cupertino.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverPage(
      title: '设置',
      slivers: [
        paddedSliver(const [
          InfoCard(
            title: '数据保存在本机',
            body: '后续账目会优先存放在本机。当前还没有数据库、同步或备份功能，因此不提供假的备份按钮。',
          ),
          InfoCard(title: '基础资料', body: '店铺、账户和分类会在本地资料模块接入后配置。'),
          InfoCard(title: 'AI记账', body: 'AI 服务尚未连接；不会在设置页收集或保存服务密钥。'),
          InfoCard(title: '安全与数据', body: '导入、导出和备份会在真实本地存储存在后启用。'),
          InfoCard(title: '显示', body: '跟随系统明暗模式和文字大小。'),
          InfoCard(title: '隐私', body: '没有网络服务接入时，页面不会上传或同步任何账目。'),
          InfoCard(title: '关于项目', body: 'Personal Finances Pro 网店账本基础版。'),
          InfoCard(
            key: ValueKey('settings-version-row'),
            title: '版本 0.1.0',
            body: 'Flutter 基础阶段。',
          ),
        ]),
      ],
    );
  }
}
