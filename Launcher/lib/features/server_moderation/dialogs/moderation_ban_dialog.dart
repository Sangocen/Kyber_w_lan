import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class ModerationBanDialog extends StatefulWidget {
  const ModerationBanDialog({required this.player, super.key});

  final ServerPlayer player;

  @override
  State<ModerationBanDialog> createState() => _ModerationBanDialogState();
}

class _ModerationBanDialogState extends State<ModerationBanDialog> {
  bool report = false;
  String? reason;
  int selectedDurationIndex = 0;
  final Map<String, Duration> _durations = {
    '1 Day': const Duration(days: 1),
    '1 Week': const Duration(days: 7),
    '2 Weeks': const Duration(days: 14),
    '1 Month': const Duration(days: 30),
    '1 Year': const Duration(days: 365),
    'Permanent': Duration.zero,
  };

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('Ban Player'.toUpperCase()),
      constraints: const BoxConstraints(
        maxWidth: 800,
        maxHeight: 600,
      ),
      content: Column(
        children: [
          Text(widget.player.name),
          const SizedBox(height: 20),
          const Text('BAN REASON'),
          const SizedBox(height: 5),
          SizedBox(
            width: 700,
            child: KyberInput(
              placeholder: 'Enter the reason for the ban',
              onChanged: (value) => reason = value,
            ),
          ),
          const SizedBox(height: 20),
          const Text('BAN DURATION'),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KyberSegmentedControl<Duration>(
                selectedIndex: selectedDurationIndex,
                items: _durations.entries
                    .map(
                      (e) => KyberSegmentedControlItem(
                        title: e.key,
                        value: e.value,
                      ),
                    )
                    .toList(),
                onSelected: (index) =>
                    setState(() => selectedDurationIndex = index),
              ),
            ],
          ),
        ],
      ),
      actions: [
        KyberButton(
          icon: Assets.icons.kblBan.svg(
            height: 20,
            color: kWhiteColor,
          ),
          onPressed: () async {
            final cubit = context.read<ModerationCubit>();
            if (cubit.state.isLocalLanHost) {
              Navigator.of(context).pop();
              return;
            }

            await cubit.banPlayer(
              id: widget.player.id,
              duration: _durations.values.elementAt(selectedDurationIndex),
              reason: reason ?? '',
            );
            if (!context.mounted) {
              return;
            }
            await cubit.loadPunishments();
            Navigator.of(context).pop();
            NotificationService.info(message: 'Player banned');
          },
          text: 'Ban Player',
        ),
        NormalButton(
          onPressed: () => setState(() => report = !report),
          iconData: report ? mt.Icons.check_circle : mt.Icons.circle_outlined,
          label: const Row(
            children: [
              Icon(mt.Icons.remove_red_eye_outlined),
              SizedBox(width: 6),
              Text('REPORT'),
            ],
          ),
        ),
        KyberButton(
          onPressed: () => Navigator.of(context).pop(),
          text: 'Cancel',
        ),
      ],
    );
  }
}
