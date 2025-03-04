// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

// Flutter imports:
import 'package:example/pages/pick_image_example.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// Package imports:
import 'package:pro_image_editor/pro_image_editor.dart';

// Project imports:
import '../utils/example_helper.dart';
import '../utils/pixel_transparent_painter.dart';

/// The example for a frame around the images
class FrameExample extends StatefulWidget {
  /// Creates a new [FrameExample] widget.
  const FrameExample({super.key});

  @override
  State<FrameExample> createState() => _FrameExampleState();
}

class _FrameExampleState extends State<FrameExample>
    with ExampleHelperState<FrameExample> {
  late final ScrollController _bottomBarScrollCtrl;

  String _frameUrl = 'assets/frame.png';

  /// Better scale experience
  final double _initScale = 10;
  final double _layerInitWidth = 200;

  final _bottomTextStyle = const TextStyle(fontSize: 10.0, color: Colors.white);

  @override
  void initState() {
    _bottomBarScrollCtrl = ScrollController();
    super.initState();
  }

  @override
  void dispose() {
    _bottomBarScrollCtrl.dispose();
    super.dispose();
  }

  void _openPicker(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    Uint8List? bytes;

    bytes = await image.readAsBytes();

    if (!mounted) return;
    await precacheImage(MemoryImage(bytes), context);
    var decodedImage = await decodeImageFromList(bytes);

    if (!mounted) return;
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      Navigator.pop(context);
    }

    editorKey.currentState!.addLayer(
      StickerLayerData(
        /// Adjust the offset position to place the image at any desired
        /// location. Note that a zero offset places the image at the center
        /// of the editor.
        offset: Offset.zero,
        scale: _initScale,
        sticker: Image.memory(
          bytes,
          width: 100,
          height: 100 /
              Size(
                decodedImage.width.toDouble(),
                decodedImage.height.toDouble(),
              ).aspectRatio,
          fit: BoxFit.cover,
        ),
      ),
    );
    setState(() {});
  }

  void _chooseCameraOrGallery() async {
    /// Open directly the gallery if the camera is not supported
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _openPicker(ImageSource.gallery);
      return;
    }

    if (!kIsWeb && Platform.isIOS) {
      await showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoTheme(
          data: const CupertinoThemeData(),
          child: CupertinoActionSheet(
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                onPressed: () => _openPicker(ImageSource.camera),
                child: const Wrap(
                  spacing: 7,
                  runAlignment: WrapAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo_camera),
                    Text('Camera'),
                  ],
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () => _openPicker(ImageSource.gallery),
                child: const Wrap(
                  spacing: 7,
                  runAlignment: WrapAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo),
                    Text('Gallery'),
                  ],
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        constraints: BoxConstraints(
          minWidth: min(MediaQuery.of(context).size.width, 360),
        ),
        builder: (context) {
          return Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                child: Wrap(
                  spacing: 45,
                  runSpacing: 30,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    MaterialIconActionButton(
                      primaryColor: const Color(0xFFEC407A),
                      secondaryColor: const Color(0xFFD3396D),
                      icon: Icons.photo_camera,
                      text: 'Camera',
                      onTap: () => _openPicker(ImageSource.camera),
                    ),
                    MaterialIconActionButton(
                      primaryColor: const Color(0xFFBF59CF),
                      secondaryColor: const Color(0xFFAC44CF),
                      icon: Icons.image,
                      text: 'Gallery',
                      onTap: () => _openPicker(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  void _toggleFrame() async {
    String newFrameUrl = _frameUrl == 'assets/frame.png'
        ? 'assets/frame1.png'
        : 'assets/frame.png';

    /// Important to precache the frame before we add it to the editor
    await precacheImage(AssetImage(newFrameUrl), context);

    _frameUrl = newFrameUrl;

    /// Mark all background-generated screenshots as broken, as the user has
    /// selected a different frame. This will trigger the screenshot to
    /// regenerate when the user selects 'Done.'
    for (var el in editorKey.currentState!.stateManager.screenshots) {
      el.broken = true;
    }

    /// Set the background bounds
    editorKey.currentState!.editorImage = EditorImage(
      /// To allow users to switch between multiple frames efficiently,
      /// consider caching the image bytes.
      byteArray: await _createTransparentBackgroundImage(),
    );
    await editorKey.currentState!.decodeImage();
  }

  Future<Uint8List> _createTransparentBackgroundImage() async {
    Size frameSize = await _frameSize;
    double width = frameSize.width;
    double height = frameSize.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final paint = Paint()..color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble()), paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final bytes = pngBytes!.buffer.asUint8List();
    // ignore: use_build_context_synchronously
    await precacheImage(MemoryImage(bytes), context);

    return bytes;
  }

  Future<Size> get _frameSize async {
    var bytes = await _frameImage.safeByteArray(context);

    var decodedImage = await decodeImageFromList(bytes);

    return Size(
      decodedImage.width.toDouble(),
      decodedImage.height.toDouble(),
    );
  }

  EditorImage get _frameImage => EditorImage(
        assetPath: _frameUrl,

        /// Optional use another option below
        ///
        /// networkUrl: ,
        /// byteArray: ,
        /// file: ,
      );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        LoadingDialog.instance.show(
          context,
          configs: const ProImageEditorConfigs(),
          theme: ThemeData.dark(),
        );

        var transparentBytes = await _createTransparentBackgroundImage();

        if (!context.mounted) return;

        /// Important to precache the frame before we add it to the editor
        await precacheImage(AssetImage(_frameUrl), context);

        LoadingDialog.instance.hide();

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LayoutBuilder(builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: const PixelTransparentPainter(
                  primary: Colors.white,
                  secondary: Color(0xFFE2E2E2),
                ),
                child: _buildEditor(transparentBytes, constraints),
              );
            }),
          ),
        );
      },
      leading: const Icon(Icons.filter_frames_outlined),
      title: const Text('Image inside a frame'),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildEditor(Uint8List transparentBytes, BoxConstraints constraints) {
    return ProImageEditor.memory(
      transparentBytes,
      key: editorKey,
      callbacks: ProImageEditorCallbacks(
        onImageEditingStarted: onImageEditingStarted,
        onImageEditingComplete: onImageEditingComplete,
        onCloseEditor: onCloseEditor,
      ),
      configs: ProImageEditorConfigs(
          designMode: platformDesignMode,
          imageGenerationConfigs: const ImageGenerationConfigs(
            enableUseOriginalBytes: false,

            /// Optional set the output format to png. Default format is jpeg
            /// outputFormat: OutputFormat.png,
          ),
          layerInteraction: const LayerInteraction(
            selectable: LayerInteractionSelectable.disabled,
          ),

          /// Crop-Rotate, Filter, Tune and Blur editors are not supported
          cropRotateEditorConfigs:
              const CropRotateEditorConfigs(enabled: false),
          filterEditorConfigs: const FilterEditorConfigs(enabled: false),
          blurEditorConfigs: const BlurEditorConfigs(enabled: false),
          customWidgets: ImageEditorCustomWidgets(
            mainEditor: CustomWidgetsMainEditor(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildFrame(editor.sizesManager.bodySize, rebuildStream),
              ],
              bottomBar: (editor, rebuildStream, key) => ReactiveCustomWidget(
                stream: rebuildStream,
                key: key,
                builder: (_) => _buildBottomBar(
                  editor,
                  constraints,
                ),
              ),
            ),
            paintEditor: CustomWidgetsPaintEditor(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
            // textEditor: CustomWidgetsTextEditor(
            //   bodyItems: (editor, rebuildStream) => [
            //     _buildFrame(editor.editorBodySize, rebuildStream),
            //   ],
            // ),
            cropRotateEditor: CustomWidgetsCropRotateEditor(
              bodyItems: (editor, rebuildStream) => [
                _buildFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
            tuneEditor: CustomWidgetsTuneEditor(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
            filterEditor: CustomWidgetsFilterEditor(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
            blurEditor: CustomWidgetsBlurEditor(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
          ),
          imageEditorTheme: const ImageEditorTheme(
            uiOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.black,
            ),
            background: Colors.transparent,
            paintingEditor: PaintingEditorTheme(background: Colors.transparent),

            /// Optionally remove background
            /// cropRotateEditor:
            ///   CropRotateEditorTheme(background:
            ///                                 Colors.transparent),
            /// filterEditor:
            ///   FilterEditorTheme(background: Colors.transparent),
            /// blurEditor:
            ///   BlurEditorTheme(background: Colors.transparent),
          ),
          stickerEditorConfigs: StickerEditorConfigs(
            enabled: false,
            initWidth: _layerInitWidth / _initScale,
            buildStickers: (setLayer, scrollController) {
              // Optionally your code to pick layers
              return const SizedBox();
            },
          )),
    );
  }

  ReactiveCustomWidget _buildFrame(Size bodySize, Stream<void> rebuildStream) {
    return ReactiveCustomWidget(
      builder: (_) => IgnorePointer(
        child: Image.asset(
          _frameUrl,
          width: bodySize.width,
          height: bodySize.height,
          fit: BoxFit.contain,
        ),
      ),
      stream: rebuildStream,
    );
  }

  Widget _buildBottomBar(
    ProImageEditorState editor,
    BoxConstraints constraints,
  ) {
    return Scrollbar(
      controller: _bottomBarScrollCtrl,
      scrollbarOrientation: ScrollbarOrientation.top,
      thickness: isDesktop ? null : 0,
      child: BottomAppBar(
        /// kBottomNavigationBarHeight is important that helper-lines will work
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            controller: _bottomBarScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: min(constraints.maxWidth, 500),
                maxWidth: 500,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FlatIconTextButton(
                      label: Text('Toggle Frame', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.filter_frames_outlined,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFrame,
                    ),
                    const VerticalDivider(width: 3),
                    FlatIconTextButton(
                      label: Text('Add Image', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: _chooseCameraOrGallery,
                    ),
                    FlatIconTextButton(
                      label: Text('Paint', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openPaintingEditor,
                    ),
                    FlatIconTextButton(
                      label: Text('Text', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.text_fields,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openTextEditor,
                    ),
                    FlatIconTextButton(
                      label: Text('Emoji', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openEmojiEditor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
