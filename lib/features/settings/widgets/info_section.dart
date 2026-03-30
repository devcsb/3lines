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
        Text('정보',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const Divider(),
        ListTile(
          title: const Text('앱 버전'),
          trailing: Text(appVersion),
        ),
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
