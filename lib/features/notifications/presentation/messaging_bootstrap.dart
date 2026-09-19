import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/messaging_registration_provider.dart';

class MessagingBootstrap extends ConsumerWidget {
  const MessagingBootstrap({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(messagingRegistrationProvider);

    return child;
  }
}
