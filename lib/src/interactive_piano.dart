import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:collection/collection.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

import 'note_position.dart';
import 'note_range.dart';

typedef OnNotePositionTapped = void Function(String position);

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

  ScrollController? _scrollController = ScrollController();
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
            widget.useAlternativeAccidentals) {}

    super.didUpdateWidget(oldWidget);
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
  Map<String, bool> noteStatus = Map<String, bool>.fromIterable(noteToQuerty.keys,
    key: (item) => item.toString(),
    value: (item) => false);
  @override
  Widget build(BuildContext context) => Container(
        child: RawKeyboardListener(
          autofocus: true,
          focusNode: FocusNode(),
          onKey: (value) {
            String? position = noteToQuerty.keys.firstWhereOrNull(
                (k) => noteToQuerty[k] == value.data.keyLabel);

            if (position != null) {
              if (value is RawKeyDownEvent) {
                if (noteStatus[position]!) {
                  return;
                }
                widget.onNotePositionTapped!(position!);
                setState(() {
                  noteStatus[position] = true;
                });
              } else if (value is RawKeyUpEvent) {
                setState(() {
                  noteStatus[position!] = false;
                });
              }
            }
            ;
          },
          child: Center(
            child: LayoutBuilder(builder: (context, constraints) {
              _lastWidth = constraints.maxWidth;
        
              final numberOfKeys = widget.noteRange.naturalPositions.length;
              _lastKeyWidth = widget.keyWidth ?? (_lastWidth - 2) / numberOfKeys;
        
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 10),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            splashRadius: 15,
                            icon: Icon(Icons.arrow_back_ios),
                            onPressed: () {
                              _scrollController!.animateTo(
                                  _scrollController!.offset - widget.keyWidth!,
                                  duration: Duration(milliseconds: 500),
                                  curve: Curves.easeOut);
                            },
                          ),
                          IconButton(
                            splashRadius: 15,
                            icon: Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              _scrollController!.animateTo(
                                  _scrollController!.offset + widget.keyWidth!,
                                  duration: Duration(milliseconds: 500),
                                  curve: Curves.easeOut);
                            },
                          ),
                        ]),
                  ),
                  Expanded(
                    child: ListView.builder(
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
                                      isPressed: noteStatus[note.name]!?true:null,
                                        notePosition: note,
                                        color: widget.naturalColor,
                                        hideNoteName: widget.hideNoteNames,
                                        isAnimated:
                                            widget.animateHighlightedNotes &&
                                                widget.highlightedNotes
                                                    .contains(note),
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
                                  left: _lastKeyWidth / 2.0 +
                                      (_lastKeyWidth * 0.02),
                                  child: FractionallySizedBox(
                                      alignment: Alignment.topCenter,
                                      heightFactor: 0.55,
                                      child: Row(
                                        children: accidentals
                                            .map(
                                              (note) => _PianoKey(
                                                isPressed: noteStatus[note.name]!?true:null,
                                                notePosition: note,
                                                color: widget.accidentalColor,
                                                hideNoteName:
                                                    widget.hideNoteNames,
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
                        }),
                  ),
                ],
              );
            }),
          ),
        ),
      );

  void Function()? _onNoteTapped(NotePosition notePosition) =>
      widget.onNotePositionTapped == null
          ? null
          : () => widget.onNotePositionTapped!(notePosition.name);
}

class _PianoKey extends StatefulWidget {
  final NotePosition notePosition;
  final double keyWidth;
  final BorderRadius _borderRadius;
  final bool hideNoteName;
  final VoidCallback? onTap;
  final bool isAnimated;
  final bool? isPressed;

  final Color _color;

  _PianoKey({
    Key? key,
    required this.notePosition,
    required this.keyWidth,
    required this.hideNoteName,
    required this.onTap,
    required this.isAnimated,
    required Color color,
    Color? highlightColor, required this.isPressed,
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
  Widget build(BuildContext context) {;
    return Stack(
        children: [
          Container(
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
                      pressed: (isPressed !=null || widget.isPressed != null)? true : null,
                      style: NeumorphicStyle(
                        shape: NeumorphicShape.concave,
                        shadowLightColor: Colors.transparent,
                        border: NeumorphicBorder(),
                        color: widget._color,
                        boxShape:
                            NeumorphicBoxShape.roundRect(widget._borderRadius),
                      ),
                      onPressed: widget.onTap!),
                )),
          ),
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: widget.keyWidth / 3,
            child: IgnorePointer(
              child: Container(
                decoration: (widget.notePosition == NotePosition.middleC)
                    ? BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: widget.hideNoteName
                    ? Container(
                        width: widget.keyWidth / 2,
                        height: widget.keyWidth / 2,
                      )
                    : Padding(
                        padding: EdgeInsets.all(2),
                        child: Column(
                          children: [
                            Text(
                              noteToQuerty[widget.notePosition.name]!,
                              textAlign: TextAlign.center,
                              textScaleFactor: 1.0,
                              style: TextStyle(
                                fontSize: widget.keyWidth / 3.5,
                                color: widget.notePosition.accidental ==
                                        Accidental.None
                                    ? (widget.notePosition == NotePosition.middleC)
                                        ? Colors.white
                                        : Colors.black
                                    : Colors.white,
                              ),
                            ),
                            Text(
                              widget.notePosition.name,
                              textAlign: TextAlign.center,
                              textScaleFactor: 1.0,
                              style: TextStyle(
                                fontSize: widget.keyWidth / 3.5,
                                color: widget.notePosition.accidental ==
                                        Accidental.None
                                    ? (widget.notePosition == NotePosition.middleC)
                                        ? Colors.white
                                        : Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
  }
}
Map<String, String> noteToQuerty = {
    'C2': '1',
    'D2': '2',
    'E2': '3',
    'F2': 'q',
    'G2': 'w',
    'A2': 'e',
    'B2': 'r',
    'C3': 't',
    'D3': 'y',
    'E3': 'u',
    'F3': 'i',
    'G3': 'o',
    'A3': 'p',
    'B3': 'a',
    'C4': 's',
    'D4': 'd',
    'E4': 'f',
    'F4': 'g',
    'G4': 'h',
    'A4': 'j',
    'B4': 'k',
    'C5': 'l',
    'D5': 'z',
    'E5': 'x',
    'F5': 'c',
    'G5': 'v',
    'A5': 'b',
    'B5': 'n',
    'C6': 'm',
    'C♯2': '!',
    'D♯2': '@',
    'F♯2': 'Q',
    'G♯2': 'W',
    'A♯2': 'E',
    'C♯3': 'T',
    'D♯3': 'Y',
    'F♯3': 'I',
    'G♯3': 'O',
    'A♯3': 'P',
    'C♯4': 'S',
    'D♯4': 'D',
    'F♯4': 'G',
    'G♯4': 'H',
    'A♯4': 'J',
    'C♯5': 'L',
    'D♯5': 'Z',
    'F♯5': 'C',
    'G♯5': 'V',
    'A♯5': 'B',
  };