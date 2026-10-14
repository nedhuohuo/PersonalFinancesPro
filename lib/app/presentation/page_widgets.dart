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
            transitionBetweenRoutes: false,
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

// Branch visibility drives read refresh on tab return, without resetting input.
enum AppTab { home, ledger, ai, settings }

class LedgerTextField extends StatefulWidget {
  LedgerTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
  }) : super(key: ValueKey(label));

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  State<LedgerTextField> createState() => _LedgerTextFieldState();
}

class _LedgerTextFieldState extends State<LedgerTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(LedgerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoTextField(
    placeholder: widget.label,
    controller: _controller,
    keyboardType: widget.keyboardType,
    padding: const EdgeInsets.all(14),
    onChanged: widget.onChanged,
  );
}

class LedgerSelectionRow<T> extends StatelessWidget {
  const LedgerSelectionRow({
    super.key,
    required this.label,
    required this.value,
    required this.display,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final String Function(T value) display;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CupertinoButton(
        color: appColor(
          context,
          CupertinoColors.secondarySystemGroupedBackground,
        ),
        onPressed:
            values.isEmpty
                ? null
                : () => showCupertinoModalPopup<void>(
                  context: context,
                  builder:
                      (context) => CupertinoActionSheet(
                        title: Text(label),
                        actions: [
                          for (final item in values)
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onChanged(item);
                              },
                              child: Text(display(item)),
                            ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$label：${value != null || values.contains(value) ? display(value as T) : '未选择'}',
          ),
        ),
      ),
    );
  }
}
