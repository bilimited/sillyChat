import 'package:flutter/material.dart';

class IconSwitchButton extends StatelessWidget {
  final bool value;
  final String label;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final double? width;
  final double? height;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  const IconSwitchButton({
    Key? key,
    required this.value,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.width,
    this.height = 30,
    this.iconSize = 18,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = HSLColor.fromColor(theme.primaryColor)
        .withSaturation(0.85)
        .withLightness(0.5)
        .toColor();
    final disabledColor = theme.disabledColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: value ? primaryColor.withOpacity(0.15) : disabledColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  icon,
                  key: ValueKey<bool>(value),
                  size: iconSize,
                  color: value ? primaryColor : disabledColor,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: value ? primaryColor : disabledColor,
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w500 : FontWeight.normal,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
