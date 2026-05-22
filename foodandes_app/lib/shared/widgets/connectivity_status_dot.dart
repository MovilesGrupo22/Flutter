import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';

class ConnectivityStatusDot extends StatefulWidget {
  final double size;
  final bool showBorder;

  const ConnectivityStatusDot({
    super.key,
    this.size = 10,
    this.showBorder = true,
  });

  @override
  State<ConnectivityStatusDot> createState() => _ConnectivityStatusDotState();
}

class _ConnectivityStatusDotState extends State<ConnectivityStatusDot> {
  bool? _isOnline;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadInitialStatus();
    _subscription = ConnectivityService.instance.isOnlineStream.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  Future<void> _loadInitialStatus() async {
    final online = await ConnectivityService.instance.isOnlineWithHandlers();
    if (!mounted) return;
    setState(() => _isOnline = online);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = _isOnline ?? false;

    return Tooltip(
      message: online ? 'Online' : 'Offline',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? Colors.green : Colors.red,
          border: widget.showBorder
              ? Border.all(color: Colors.white, width: 1.5)
              : null,
        ),
      ),
    );
  }
}

class ConnectivityAwareProfileIcon extends StatelessWidget {
  const ConnectivityAwareProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.person_outline),
        Positioned(
          right: -1,
          top: -1,
          child: ConnectivityStatusDot(size: 9),
        ),
      ],
    );
  }
}
