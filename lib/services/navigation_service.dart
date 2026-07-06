import 'package:flutter/material.dart';
import 'package:uddoygi/push/message_notification.dart';

class NavigationService {
  static final NavigationService instance = NavigationService._();
  NavigationService._();

  GlobalKey<NavigatorState> get navigatorKey => messageNavigatorKey;
  
  final ValueNotifier<String?> currentRouteNotifier = ValueNotifier<String?>(null);

  String? get currentRoute => currentRouteNotifier.value;

  void onRouteChanged(String? route) {
    currentRouteNotifier.value = route;
  }
}

class RouteObserverService extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    NavigationService.instance.onRouteChanged(route.settings.name);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    NavigationService.instance.onRouteChanged(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    NavigationService.instance.onRouteChanged(newRoute?.settings.name);
  }
}
