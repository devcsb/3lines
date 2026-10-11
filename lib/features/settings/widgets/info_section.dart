import 'package:flutter/material.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.appVersion});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '정보',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '3Lines는 기록을 자체 서버로 전송하지 않아요. 운영체제 설정에 따라 앱 데이터가 백업될 수 있어요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(title: const Text('앱 버전'), trailing: Text(appVersion)),
        Semantics(
          label: '오픈소스 라이선스 보기',
          child: ListTile(
            title: const Text('오픈소스 라이선스'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '3Lines',
              applicationVersion: appVersion,
            ),
          ),
        ),
      ],
    );
  }
}
