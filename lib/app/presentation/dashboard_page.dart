import 'package:flutter/cupertino.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    return AppSliverPage(
      title: '平台外经营账本',
      compactTitle: '首页',
      slivers: [
        paddedSliver([
          InfoCard(
            title: '本月实付支出',
            body: '账本尚未接入本地记录，当前不能计算真实金额。这里不会用示例交易冒充利润或亏损。',
            child: Text(
              '待记账',
              style: textTheme.textStyle.copyWith(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                color: appColor(context, CupertinoColors.label),
              ),
            ),
          ),
          const InfoCard(title: '当前厂家待付款', body: '采购单还没有连接到本地持久化，待付款余额暂不显示数字。'),
          const InfoCard(
            title: '本月问题件回收',
            body: '问题件收入会在正式账本接入后单独统计，不混入普通平台收入。',
          ),
          const InfoCard(
            title: '范围说明',
            body: '本 App 只记录平台外经营流水；不含平台订单收入，不代表利润或亏损。',
          ),
        ]),
      ],
    );
  }
}
