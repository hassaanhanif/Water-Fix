import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Full-width black pill CTA button with sky-blue circular right arrow (Screens 3, 5, 8, 9, 10, 11).
class PrimaryArrowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryArrowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<PrimaryArrowButton> createState() => _PrimaryArrowButtonState();
}

class _PrimaryArrowButtonState extends State<PrimaryArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLoading && widget.onPressed != null;
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: double.infinity,
          height: 62,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: WaterFixColors.primaryBlack,
              disabledBackgroundColor:
                  WaterFixColors.primaryBlack.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.only(left: 24, right: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  transform: Matrix4.translationValues(
                    _pressed ? 3.0 : 0.0,
                    0.0,
                    0.0,
                  ),
                  decoration: const BoxDecoration(
                    color: WaterFixColors.skyBlue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: WaterFixColors.primaryBlack,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          color: WaterFixColors.primaryBlack,
                          size: 22,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sky-blue pill button with bold black text (Screens 1, 2, 6, 7, 13).
class SkyBlueButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final bool fullWidth;
  final double height;
  final bool isLoading;

  const SkyBlueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.fullWidth = true,
    this.height = 52,
    this.isLoading = false,
  });

  @override
  State<SkyBlueButton> createState() => _SkyBlueButtonState();
}

class _SkyBlueButtonState extends State<SkyBlueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLoading && widget.onPressed != null;
    final btn = Listener(
      onPointerDown: enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onPointerCancel: enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: WaterFixColors.skyBlue,
            foregroundColor: WaterFixColors.primaryBlack,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            minimumSize: Size(widget.fullWidth ? double.infinity : 0, widget.height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
          ),
          child: Row(
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (widget.leadingIcon != null) ...[
                Icon(
                  widget.leadingIcon,
                  size: 18,
                  color: WaterFixColors.primaryBlack,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return widget.fullWidth
        ? SizedBox(width: double.infinity, height: widget.height, child: btn)
        : btn;
  }
}

/// Rounded square icon button for back `<`, close `✕`, bell, or heart.
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? backgroundColor;
  final Color? iconColor;

  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor ?? WaterFixColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: backgroundColor != null
                    ? Colors.transparent
                    : WaterFixColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? WaterFixColors.primaryBlack,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: WaterFixColors.skyBlue,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: WaterFixColors.scaffoldBg,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.primaryBlack,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selectable pill chip matching capacity chips, sort tabs, and category chips.
class SelectablePillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  const SelectablePillChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected
              ? WaterFixColors.primaryBlack
              : WaterFixColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? WaterFixColors.primaryBlack
                : WaterFixColors.cardBorder,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : WaterFixColors.primaryBlack,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
