import 'package:flutter/cupertino.dart';

const appPadding = 16.0;

Color appColor(BuildContext context, CupertinoDynamicColor color) {
  return CupertinoDynamicColor.resolve(color, context);
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.child,
  });

  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColor(
          context,
          CupertinoColors.secondarySystemGroupedBackground,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: appColor(context, CupertinoColors.separator)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(appPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: appColor(context, CupertinoColors.secondaryLabel),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (child != null) ...[const SizedBox(height: 12), child!],
          ],
        ),
      ),
    );
  }
}

class AppSliverPage extends StatelessWidget {
  const AppSliverPage({
    super.key,
    required this.title,
    required this.slivers,
    this.compactTitle,
  });

  final String title;
  final String? compactTitle;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: true,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            middle: Text(compactTitle ?? title),
            largeTitle: Text(title),
          ),
          SliverSafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(horizontal: appPadding),
            sliver: SliverList.list(children: const [SizedBox(height: 12)]),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

SliverSafeArea paddedSliver(List<Widget> children) {
  return SliverSafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(appPadding, 0, appPadding, appPadding),
    sliver: SliverList.separated(
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: children.length,
    ),
  );
}
