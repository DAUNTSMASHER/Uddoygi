import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';

class FactoryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const FactoryMetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: UddoygiDesign.borderM,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: UddoygiDesign.borderM,
            border: Border.all(color: UddoygiDesign.surface),
            boxShadow: UddoygiDesign.shadowSoft,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 60,
                  color: accentColor.withOpacity(0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(UddoygiDesign.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: UddoygiDesign.borderS,
                          ),
                          child: Icon(icon, color: accentColor, size: 16),
                        ),
                        const SizedBox(width: UddoygiDesign.space8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.banglaHeading(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.banglaData(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: UddoygiDesign.factoryHeroRed,
                      ),
                    ).animate().fadeIn().scale(delay: 50.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
