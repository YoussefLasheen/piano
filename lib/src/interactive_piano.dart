import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:collection/collection.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

import 'note_position.dart';
import 'note_range.dart';

typedef OnNotePositionTapped = void Function(NotePosition position);

/// Renders a scrollable interactive piano.
class InteractivePiano extends StatefulWidget {
  /// The range of notes to create interactive keys for.
  final NoteRange noteRange;

  /// The range of notes to highlight.
  final List<NotePosition> highlightedNotes;

  /// The color with which to draw highlighted notes; blended with the color of the key.
  final Color highlightColor;

  /// Color to render "natural" notes—typically white.
  final Color naturalColor;

  /// Color to render "accidental" notes (sharps and flats)—typically black.
  final Color accidentalColor;

  /// Whether to apply a repeating press animation to highlighted notes.
  final bool animateHighlightedNotes;

  /// Whether to treat tapped notes as flats instead of sharps. Affects the value passed to `onNotePositionTapped`.
  final bool useAlternativeAccidentals;

  /// Whether to hide note names on keys.
  final bool hideNoteNames;

  /// Whether to hide the scroll bar, that appears below the keys.
  final bool hideScrollbar;

  /// Leave as `null` to have keys sized automatically to fit the width of the widget.
  final double? keyWidth;

  /// Callback for interacting with piano keys.
  final OnNotePositionTapped? onNotePositionTapped;

  /// Set and change at any time (i.e. with `setState`) to cause the piano to scroll so that the desired note is centered.
  final NotePosition? noteToScrollTo;

  /// See individual parameters for more information. The only required parameter
  /// is `noteRange`. Since the widget wraps a scroll view and therefore has no
  /// "intrinsic" size, be sure to use inside a parent that specifies one.
  ///
  /// For example:
  /// ```
  /// SizedBox(
  ///   width: 300,
  ///   height: 100,
  ///   child: InteractivePiano(
  ///     noteRange: NoteRange.forClefs(
  ///       [Clef.Treble],
  ///       extended: true
  ///     )
  ///   )
  /// )
  /// ```
  ///
  /// Normally you'll want to pass `keyWidth`—if you don't, the entire range of notes
  /// will be squashed into the width of the widget.
  InteractivePiano(
      {Key? key,
      required this.noteRange,
      this.highlightedNotes = const [],
      this.highlightColor = Colors.red,
      this.naturalColor = Colors.white,
      this.accidentalColor = Colors.black,
      this.animateHighlightedNotes = false,
      this.useAlternativeAccidentals = false,
      this.hideNoteNames = false,
      this.hideScrollbar = false,
      this.onNotePositionTapped,
      this.noteToScrollTo,
      this.keyWidth})
      : super(key: key);

  @override
  _InteractivePianoState createState() => _InteractivePianoState();
}

class _InteractivePianoState extends State<InteractivePiano> {
  /// We group notes into blocks of contiguous accidentals, since they need to be stacked
  late List<List<NotePosition>> _noteGroups;

  ScrollController? _scrollController;
  double _lastWidth = 0.0, _lastKeyWidth = 0.0;

  @override
  void initState() {
    _updateNotePositions();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InteractivePiano oldWidget) {
    if (oldWidget.noteRange != widget.noteRange ||
        oldWidget.useAlternativeAccidentals !=
            widget.useAlternativeAccidentals) {
      _updateNotePositions();
    }

    final noteToScrollTo = widget.noteToScrollTo;
    if (noteToScrollTo != null && oldWidget.noteToScrollTo != noteToScrollTo) {
      _scrollController?.animateTo(
          _computeScrollOffsetForNotePosition(noteToScrollTo),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }

    super.didUpdateWidget(oldWidget);
  }

  double _computeScrollOffsetForNotePosition(NotePosition notePosition) {
    final closestNatural = notePosition.copyWith(accidental: Accidental.None);

    final int index = widget.noteRange.naturalPositions.indexOf(closestNatural);

    if (index == -1 || _lastWidth == 0.0 || _lastKeyWidth == 0.0) {
      return 0.0;
    }

    return (index * _lastKeyWidth + _lastKeyWidth / 2 - _lastWidth / 2);
  }

  _updateNotePositions() {
    final notePositions = widget.noteRange.allPositions;

    if (widget.useAlternativeAccidentals) {
      for (int i = 0; i < notePositions.length; i++) {
        notePositions[i] =
            notePositions[i].alternativeAccidental ?? notePositions[i];
      }
    }

    _noteGroups = notePositions
        .splitBeforeIndexed((index, _) =>
            _.accidental == Accidental.None &&
            notePositions[index - 1].accidental == Accidental.None)
        .toList();
  }

  @override
  Widget build(BuildContext context) => Container(
        child: Center(
          child: LayoutBuilder(builder: (context, constraints) {
            _lastWidth = constraints.maxWidth;

            final numberOfKeys = widget.noteRange.naturalPositions.length;
            _lastKeyWidth = widget.keyWidth ?? (_lastWidth - 2) / numberOfKeys;

            if (_scrollController == null) {
              double scrollOffset = _computeScrollOffsetForNotePosition(
                  widget.noteToScrollTo ?? NotePosition.middleC);
              _scrollController =
                  ScrollController(initialScrollOffset: scrollOffset);
            }

            final showScrollbar = !widget.hideScrollbar &&
                (numberOfKeys * _lastKeyWidth) > _lastWidth;

            return ListView.builder(
                    shrinkWrap: true,
                    physics: widget.hideScrollbar
                        ? NeverScrollableScrollPhysics()
                        : ClampingScrollPhysics(),
                    itemCount: _noteGroups.length,
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (BuildContext context, int index) {
                      final naturals = _noteGroups[index]
                          .where((_) => _.accidental == Accidental.None);
                      final accidentals = _noteGroups[index]
                          .where((_) => _.accidental != Accidental.None);

                      return Stack(
                        children: [
                          Row(
                            children: naturals
                                .map((note) => _PianoKey(
                                    notePosition: note,
                                    color: widget.naturalColor,
                                    hideNoteName: widget.hideNoteNames,
                                    isAnimated: widget
                                            .animateHighlightedNotes &&
                                        widget.highlightedNotes.contains(note),
                                    highlightColor:
                                        widget.highlightedNotes.contains(note)
                                            ? widget.highlightColor
                                            : null,
                                    keyWidth: _lastKeyWidth,
                                    onTap: _onNoteTapped(note)))
                                .toList(),
                          ),
                          Positioned(
                              top: 0.0,
                              bottom: 0.0,
                              left:
                                  _lastKeyWidth / 2.0 + (_lastKeyWidth * 0.02),
                              child: FractionallySizedBox(
                                  alignment: Alignment.topCenter,
                                  heightFactor: 0.55,
                                  child: Row(
                                    children: accidentals
                                        .map(
                                          (note) => _PianoKey(
                                            notePosition: note,
                                            color: widget.accidentalColor,
                                            hideNoteName: widget.hideNoteNames,
                                            isAnimated: widget
                                                    .animateHighlightedNotes &&
                                                widget.highlightedNotes
                                                    .contains(note),
                                            highlightColor: widget
                                                    .highlightedNotes
                                                    .contains(note)
                                                ? widget.highlightColor
                                                : null,
                                            keyWidth: _lastKeyWidth,
                                            onTap: _onNoteTapped(note),
                                          ),
                                        )
                                        .toList(),
                                  ))),
                        ],
                      );
                    });
          }),
        ),
      );

  void Function()? _onNoteTapped(NotePosition notePosition) =>
      widget.onNotePositionTapped == null
          ? null
          : () => widget.onNotePositionTapped!(notePosition);
}

class _PianoKey extends StatefulWidget {
  final NotePosition notePosition;
  final double keyWidth;
  final BorderRadius _borderRadius;
  final bool hideNoteName;
  final VoidCallback? onTap;
  final bool isAnimated;

  final Color _color;

  _PianoKey({
    Key? key,
    required this.notePosition,
    required this.keyWidth,
    required this.hideNoteName,
    required this.onTap,
    required this.isAnimated,
    required Color color,
    Color? highlightColor,
  })  : _borderRadius = BorderRadius.only(
            bottomLeft: Radius.circular(keyWidth * 0.2),
            bottomRight: Radius.circular(keyWidth * 0.2)),
        _color = (highlightColor != null)
            ? Color.lerp(color, highlightColor, 0.5) ?? highlightColor
            : color,
        super(key: key);

  @override
  State<_PianoKey> createState() => _PianoKeyState();
}

class _PianoKeyState extends State<_PianoKey> {
  bool? isPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: widget.keyWidth,
        padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: (widget.keyWidth *
                    (widget.notePosition.accidental == Accidental.None
                        ? 0.02
                        : 0.04))
                .ceilToDouble()),
        child: MouseRegion(
            onEnter: (event) {
              if (event.down) {
                setState(() {
                  isPressed = true;
                });
                Future.delayed(Duration(milliseconds: 150), () {
                  setState(() {
                    isPressed = null;
                  });
                });

                widget.onTap!();
              }
            },
            child: SizedBox(
              height: double.infinity,
              child: NeumorphicButton(
                  pressed: isPressed,
                  drawSurfaceAboveChild: false,
                  style: NeumorphicStyle(
                    border: NeumorphicBorder(),
                    color: widget._color,
                    boxShape:
                        NeumorphicBoxShape.roundRect(widget._borderRadius),
                  ),
                  onPressed:  widget.onTap!),
            )),
      );
}
