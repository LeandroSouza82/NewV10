import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../views/notificacoes/widgets/notification_icon_badge.dart';
import 'vehicle_alert_badge.dart';

class CustomAppBar extends StatelessWidget {
  final String driverName;
  final String? avatarUrl;
  final bool isOnline;
  final bool isUpdatingStatus;
  final VoidCallback? onToggleStatus;

  const CustomAppBar({
    super.key,
    this.driverName = 'Leandro', // Valor padrão temporário
    this.avatarUrl,
    this.isOnline = true,
    this.isUpdatingStatus = false,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.backgroundBody.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Ícone de Menu com efeito de clique sutil
                  Builder(
                    builder: (context) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Scaffold.of(context).openDrawer();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: VehicleAlertBadge(
                              child: NotificationIconBadge(
                                child: Icon(
                                  Icons.menu_rounded,
                                  color: isDark ? AppColors.textWhite : Colors.black87,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Título Elegante
                  Text(
                    'V10 Delivery',
                    style: TextStyle(
                      color: isDark ? AppColors.textWhite : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),

                // Perfil e Status Animado
                GestureDetector(
                  onTap: isUpdatingStatus ? null : onToggleStatus,
                  child: Row(
                    children: [
                      // Animação de Pulso ou Loading
                      if (isUpdatingStatus)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textWhite),
                          ),
                        )
                      else
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.5, end: 1.0),
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? Colors.green : Colors.red,
                                boxShadow: [
                                  if (isOnline)
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: value * 0.6),
                                      blurRadius: value * 8,
                                      spreadRadius: value * 2,
                                    ),
                                ],
                              ),
                            );
                          },
                          onEnd: () {},
                        ),
                      
                      // Avatar do Motorista
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.5), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.cardBackground,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                          child: avatarUrl == null 
                              ? const Icon(Icons.person, color: AppColors.textWhite, size: 20)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
