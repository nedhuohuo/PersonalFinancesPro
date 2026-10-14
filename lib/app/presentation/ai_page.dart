import 'package:flutter/cupertino.dart';
import 'package:personal_finances_pro/app/presentation/page_widgets.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: true,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                const CupertinoSliverNavigationBar(largeTitle: Text('AI记账')),
                paddedSliver([
                  const _MessageBubble(
                    title: 'AI功能尚未接入',
                    body: '本地账本已连接；AI 服务尚未接入。这里不生成草稿、不确认入账，也不接收密钥。',
                  ),
                  InfoCard(
                    title: '待确认草稿',
                    body: '没有可确认的 AI 草稿。AI 草稿与确认流程尚未接入。',
                    child: CupertinoButton.filled(
                      key: const ValueKey('ai-confirm-button'),
                      minSize: 48,
                      onPressed: null,
                      child: const Text('确认入账（未接入）'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const _DisabledComposer(),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: InfoCard(title: title, body: body),
      ),
    );
  }
}

class _DisabledComposer extends StatelessWidget {
  const _DisabledComposer();

  @override
  Widget build(BuildContext context) {
    final separator = appColor(context, CupertinoColors.separator);
    final background = appColor(context, CupertinoColors.systemBackground);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: separator, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CupertinoTextField(
                key: const ValueKey('ai-composer'),
                minLines: 1,
                maxLines: 3,
                readOnly: true,
                placeholder: 'AI尚未接入，暂不能发送',
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: appColor(
                    context,
                    CupertinoColors.secondarySystemGroupedBackground,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: separator),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton.filled(
              key: const ValueKey('ai-send-button'),
              minSize: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: null,
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }
}
