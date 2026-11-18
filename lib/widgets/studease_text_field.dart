import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

/// Input styled like the prototype: soft slate fill, 16px radius, indigo focus.
class StudEaseTextField extends StatefulWidget {
  const StudEaseTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.prefixIcon,
    this.autofillHints,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final int maxLines;
  final FocusNode? focusNode;

  @override
  State<StudEaseTextField> createState() => _StudEaseTextFieldState();
}

class _StudEaseTextFieldState extends State<StudEaseTextField> {
  late bool _hidden = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.surfaces.border),
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _hidden,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.surfaces.ink,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: context.surfaces.canvas,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(
                widget.prefixIcon,
                size: 18,
                color: context.surfaces.inkFaint,
              ),
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: () => setState(() => _hidden = !_hidden),
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: context.surfaces.inkFaint,
                ),
              )
            : null,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.surfaces.inkMuted,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: context.surfaces.brandInk,
        ),
        hintStyle: TextStyle(fontSize: 12.5, color: context.surfaces.inkFaint),
        errorStyle: TextStyle(
          fontSize: 10.5,
          color: context.surfaces.dangerInk,
        ),
        border: baseBorder,
        enabledBorder: baseBorder,
        disabledBorder: baseBorder.copyWith(
          borderSide: BorderSide(color: context.surfaces.divider),
        ),
        focusedBorder: baseBorder.copyWith(
          borderSide: BorderSide(color: context.surfaces.brandInk, width: 1.4),
        ),
        errorBorder: baseBorder.copyWith(
          borderSide: BorderSide(color: context.surfaces.dangerInk),
        ),
        focusedErrorBorder: baseBorder.copyWith(
          borderSide: BorderSide(color: context.surfaces.dangerInk, width: 1.4),
        ),
      ),
    );
  }
}
