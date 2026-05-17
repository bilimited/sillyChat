import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppCardOptionItem<T> {
  final T value;
  final Widget child;

  const AppCardOptionItem({
    required this.value,
    required this.child,
  });
}

class AppOptionCard<T> extends StatefulWidget {
  final Widget? leading;
  final String title;
  final Widget? subTitle;
  final List<AppCardOptionItem<T>> options;
  final ValueChanged<T>? onSelected;
  final VoidCallback? onTap;

  const AppOptionCard({
    super.key,
    this.leading,
    required this.title,
    this.subTitle,
    this.options = const [],
    this.onSelected,
    this.onTap,
  });

  @override
  State<AppOptionCard<T>> createState() => _AppOptionCardState<T>();
}

class _AppOptionCardState<T> extends State<AppOptionCard<T>> {
  bool _hovering = false;

  bool get _isDesktopLike {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  bool get _showMenuButton {
    if (!_hasOptions) return false;
    return !_isDesktopLike || _hovering;
  }

  bool get _hasOptions => widget.options.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cardChild = Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      elevation: 0,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.leading != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: widget.leading!,
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subTitle != null) ...[
                      const SizedBox(height: 6),
                      widget.subTitle!,
                    ],
                  ],
                ),
              ),
              if (_hasOptions) ...[
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: _showMenuButton ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: !_showMenuButton,
                    child: PopupMenuButton<T>(
                      icon: Icon(
                        Icons.more_vert,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      color: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: widget.onSelected,
                      itemBuilder: (context) => widget.options
                          .map(
                            (item) => PopupMenuItem<T>(
                              value: item.value,
                              child: item.child,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (_isDesktopLike) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: cardChild,
      );
    }

    return cardChild;
  }
}
