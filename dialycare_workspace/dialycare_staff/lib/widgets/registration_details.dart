import 'package:flutter/material.dart';

import '../models/notification_delivery.dart';
import '../services/notifications/providers.dart';
import '../services/staff_store.dart';
import '../theme/staff_theme.dart';
import 'mobile_access_details.dart';

class RegistrationDetails extends StatelessWidget {
  const RegistrationDetails({
    super.key,
    required this.recipient,
    required this.store,
    this.manageAccess = false,
    this.showDelivery = true,
  });
  final NotificationRecipient recipient;
  final StaffStore store;
  final bool manageAccess;
  final bool showDelivery;
  @override
  Widget build(BuildContext context) {
    if (!showDelivery) {
      return MobileAccessDetails(
        recipient: recipient,
        store: store,
        manageAccess: false,
      );
    }
    final registration = recipient.registration;
    final color = registration.hasValidPush
        ? const Color(0xFF2B8058)
        : registration.status == AppRegistrationStatus.unavailable
        ? Colors.orange.shade800
        : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MobileAccessDetails(
            recipient: recipient,
            store: store,
            manageAccess: manageAccess,
          ),
          const Text(
            'Device / delivery status',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            children: [
              Icon(Icons.circle, size: 8, color: color),
              Text(
                registration.label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!registration.backendVerified)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text(
                'Backend registration has not been verified.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          if (registration.backendVerified && registration.lastActivity != null)
            Text(
              'Last connected: ${shortDate(registration.lastActivity!)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          if (store.shared)
            SelectableText(
              'Account ID: ${recipient.displayId}',
              style: const TextStyle(fontSize: 11),
            ),
          Text(
            store.shared
                ? 'In-app notifications · Push Not Configured · SMS Not Configured'
                : registration.notificationsEnabled
                ? 'Delivery: ${store.deliveryService.routeLabel(recipient)}'
                : 'Notifications disabled',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
