part of 'music_immersive_player.dart';

const List<Color> _visualColorPalette = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFDCE6E8),
  Color(0xFF8DA2A7),
  Color(0xFF72D6C9),
  Color(0xFF58B7D9),
  Color(0xFF6F92E8),
  Color(0xFFA78BE8),
  Color(0xFFF2D986),
  Color(0xFFF0A46B),
  Color(0xFFE87878),
  Color(0xFFE97FA9),
  Color(0xFF83C982),
];

class _VisualColorField extends StatelessWidget {
  const _VisualColorField({
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final MusicImmersivePalette palette;
  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: palette.text)),
      trailing: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openPicker(context),
          child: Container(
            width: 42,
            height: 30,
            decoration: BoxDecoration(
              color: value,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
            ),
          ),
        ),
      ),
      onTap: () => _openPicker(context),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showDialog<Color>(
      context: context,
      builder:
          (context) => _VisualColorDialog(
            palette: palette,
            title: label,
            initialColor: value,
          ),
    );
    if (selected != null) {
      onChanged(selected);
    }
  }
}

class _VisualColorDialog extends StatefulWidget {
  const _VisualColorDialog({
    required this.palette,
    required this.title,
    required this.initialColor,
  });

  final MusicImmersivePalette palette;
  final String title;
  final Color initialColor;

  @override
  State<_VisualColorDialog> createState() => _VisualColorDialogState();
}

class _VisualColorDialogState extends State<_VisualColorDialog> {
  late HSVColor _color;

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _color.toColor();
    return AlertDialog(
      backgroundColor: const Color(0xFF111A20),
      title: Text(widget.title, style: TextStyle(color: widget.palette.text)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _visualColorPalette
                  .map((preset) {
                    final selected = preset.toARGB32() == color.toARGB32();
                    return Tooltip(
                      message: _colorHex(preset),
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: _colorHex(preset),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap:
                              () => setState(
                                () => _color = HSVColor.fromColor(preset),
                              ),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: preset,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    selected
                                        ? widget.palette.text
                                        : Colors.white.withValues(alpha: 0.22),
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child:
                                selected
                                    ? Icon(
                                      Icons.check_rounded,
                                      size: 17,
                                      color:
                                          preset.computeLuminance() > 0.52
                                              ? Colors.black
                                              : Colors.white,
                                    )
                                    : null,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 14),
            _ColorSlider(
              label: l10n.musicVisualizerColorHue,
              value: _color.hue,
              max: 360,
              onChanged:
                  (value) => setState(() => _color = _color.withHue(value)),
            ),
            _ColorSlider(
              label: l10n.musicVisualizerColorSaturation,
              value: _color.saturation,
              max: 1,
              onChanged:
                  (value) =>
                      setState(() => _color = _color.withSaturation(value)),
            ),
            _ColorSlider(
              label: l10n.musicVisualizerColorBrightness,
              value: _color.value,
              max: 1,
              onChanged:
                  (value) => setState(() => _color = _color.withValue(value)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }

  String _colorHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        AppSlider(
          value: value,
          min: 0,
          max: max,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
