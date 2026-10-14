import 'package:flutter/cupertino.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverPage(
      title: '账本',
      slivers: [
        paddedSliver(const [
          InfoCard(
            title: '还没有账目',
            body: '本地账本尚未连接到记录存储，因此这里不是零支出的结论，只是暂时没有可读取的数据。',
          ),
          InfoCard(title: '现金账', body: '收入、支出和平台外差额会在本地持久化接入后显示。'),
          InfoCard(title: '采购单', body: '采购应付、已付款和待付会分开展示；当前不使用样例余额。'),
          InfoCard(title: '快递预付', body: '充值、消耗和记录余额会在快递记录接入后显示。'),
        ]),
      ],
    );
  }
}
