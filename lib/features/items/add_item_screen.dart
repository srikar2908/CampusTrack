import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/app_constants.dart';
import '../../../models/item_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/items_provider.dart';
import '../../../common/loading_indicator.dart';
import 'package:path/path.dart' as path;

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final locationController = TextEditingController();

  final ImagePicker picker = ImagePicker();
  static const int kMaxDimension = 1600;
  static const int kQuality = 80;

  List<File> _mobileFiles = [];
  List<Uint8List> _webFiles = [];
  List<Uint8List> _compressedFiles = [];
  List<String> _originalFileNames = [];

  bool isLoading = false;
  String selectedType = AppConstants.lostType;

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    locationController.dispose();
    super.dispose();
  }

  // 📸 Capture image using camera
  Future<void> captureImage() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not supported on Web')),
        );
        return;
      }

      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null) return;

      final file = File(picked.path);
      final c = await _compressMobileToBytes(file);

      setState(() {
        _mobileFiles.add(file);
        _compressedFiles.add(c);
        _originalFileNames.add(path.basename(file.path));
      });
    } catch (e) {
      debugPrint('❌ Camera error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Camera error: $e')));
    }
  }

  // 🖼 Pick multiple images from gallery
  Future<void> pickImages() async {
    try {
      if (kIsWeb) {
        final pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isEmpty) return;

        List<Uint8List> compressed = [];
        List<String> names = [];

        for (var picked in pickedFiles) {
          final bytes = await picked.readAsBytes();
          final c = await _compressWeb(bytes);
          compressed.add(c);
          names.add(picked.name);
        }

        setState(() {
          _webFiles.addAll(compressed);
          _compressedFiles.addAll(compressed);
          _originalFileNames.addAll(names);
        });
      } else {
        final pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isEmpty) return;

        List<Uint8List> compressed = [];
        List<File> files = [];
        List<String> names = [];

        for (var picked in pickedFiles) {
          final file = File(picked.path);
          final c = await _compressMobileToBytes(file);
          files.add(file);
          compressed.add(c);
          names.add(path.basename(file.path));
        }

        setState(() {
          _mobileFiles.addAll(files);
          _compressedFiles.addAll(compressed);
          _originalFileNames.addAll(names);
        });
      }
    } catch (e) {
      debugPrint('❌ Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Image error: $e')));
      }
    }
  }

  Future<Uint8List> _compressWeb(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? kMaxDimension : null,
      height: decoded.height > decoded.width ? kMaxDimension : null,
      interpolation: img.Interpolation.average,
    );

    final out = img.encodeJpg(resized, quality: kQuality);
    return Uint8List.fromList(out);
  }

  Future<Uint8List> _compressMobileToBytes(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: kQuality,
      format: CompressFormat.jpeg,
      minWidth: kMaxDimension,
      minHeight: kMaxDimension,
    );
    return result ?? await file.readAsBytes();
  }

  /// 🧾 Submit item
  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
      final user = authProvider.appUser;
      if (user == null) throw Exception('User not authenticated');

      final item = ItemModel(
        id: '',
        title: titleController.text.trim(),
        description: descController.text.trim(),
        location: locationController.text.trim(),
        itemDateTime: DateTime.now(),
        imagePaths: [],
        userId: user.uid,
        officeId: user.officeId,
        status: AppConstants.pendingStatus,
        type: selectedType,
        dateTime: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await itemsProvider.addItem(
        item,
        imagesBytes: _compressedFiles,
        originalFileNames: _originalFileNames,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Item submitted successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previews = kIsWeb
        ? _webFiles
            .map((e) => Image.memory(e, height: 100, width: 100, fit: BoxFit.cover))
            .toList()
        : _mobileFiles
            .map((e) => Image.file(e, height: 100, width: 100, fit: BoxFit.cover))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Report Lost/Found Item')),
      body: isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                          labelText: 'Title', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Description', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(
                          labelText: 'Location', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Select Type', border: OutlineInputBorder()),
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: AppConstants.lostType, child: Text('Lost')),
                        DropdownMenuItem(value: AppConstants.foundType, child: Text('Found')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    if (previews.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: previews.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: previews[i],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // 🧩 Buttons for Camera and Gallery
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: captureImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                        ),
                        ElevatedButton.icon(
                          onPressed: pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick from Gallery'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitItem,
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
