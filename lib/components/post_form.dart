import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uni_market/components/image_carousel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class PostForm extends StatefulWidget {
  const PostForm({Key? key}) : super(key: key);

  @override
  State<PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<PostForm> {
  final GlobalKey<FormBuilderState> _fbKey = GlobalKey<FormBuilderState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final double _maxPrice = 10000.0;

  bool submitting = false;
  List<String> _imageDataUrls = [];

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _fbKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title box
          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'title',
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(labelText: 'Title'),
            controller: _titleController,
            validator: FormBuilderValidators.required(context),
            maxLines: 1,
            maxLength: 30, // Set a maximum character limit
          ),
          // Description
          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'description',
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
            validator: FormBuilderValidators.required(context),
            maxLength: 150, // Set a maximum character limit
          ),
          // Price Box
          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'price',
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Price',
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(context),
              (value) {
                // Custom validator for price format
                if (value != null && !isValidPrice(value)) {
                  return 'Invalid price format';
                }
                if (value != null && double.parse(value) > _maxPrice) {
                  return 'Price cannot exceed \$${_maxPrice.toStringAsFixed(2)}';
                }
                return null;
              },
            ]),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          // Condition Box
          FormBuilderDropdown(
            name: 'condition',
            hint: const Text('Select Condition'),
            items: ['USED', 'NEW', 'WORN']
                .map((condition) => DropdownMenuItem(
                      value: condition,
                      child: Text(condition),
                    ))
                .toList(),
            validator: FormBuilderValidators.required(context),
          ),
          const SizedBox(height: 38),
          ElevatedButton(
            onPressed: () async {
              if (kIsWeb) {
                List<XFile> clientImageFiles = await multiImagePicker();

                if (clientImageFiles.isNotEmpty) {
                  List<String> dataUrls =
                      await convertXFilesToDataUrls(clientImageFiles);

                  // Show the pop-up dialog for image confirmation
                  BuildContext? dialogContext;
                  bool confirmSelection = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      // Assign the captured context
                      dialogContext = context;

                      return ImageCarouselDialog(imageDataUrls: dataUrls);
                    },
                  );

                  // Check if the user confirmed the selection
                  if (confirmSelection == true) {
                    setState(() {
                      _imageDataUrls = dataUrls;
                    });
                  }
                }
              } else {
                // HERE LIES MOBILE IMAGE SELECTION CODE
                print("not on web");
              }
            },
            child: Column(
              children: [
                const Text("Upload Image(s)", style: TextStyle(fontSize: 12)),
                if (_imageDataUrls.isNotEmpty)
                  const Text("✅",
                      style: TextStyle(fontSize: 20, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 29),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shadowColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.0))),
            onPressed: () async {
              // Check form data validitiy
              if (_fbKey.currentState!.saveAndValidate()) {
                // Store form data in Map for db upload
                Map<String, dynamic> formData =
                    Map.from(_fbKey.currentState!.value);

                _createPost(context, formData, _imageDataUrls);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Helper functions for input form to database document
  Future<void> _createPost(
    BuildContext context,
    Map<String, dynamic> formData,
    List<String> imageDataUrls,
  ) async {
    try {
      // Pop Up Post Creation Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating your post')),
      );

      // Update Post Form State
      setState(() => submitting = true);

      // Upload images to firebase storage before generating post document
      try {
        Completer<List<String>> completer = Completer<List<String>>();
        uploadImages(imageDataUrls, completer);
        List<String> downloadUrls = await completer.future;
        formData["images"] = downloadUrls;
      } catch (e) {
        print("Error uploading images: $e");
        return;
      }

      String? marketplaceId;
      String? schoolId;
      String? sellerId = "";

      // Initialize db connection for current user
      var currentUser = FirebaseAuth.instance.currentUser;

      // Conditionally set userId from current user email
      if (currentUser != null) {
        sellerId = currentUser.email;
      }

      // get users marketplace ID(s) and fill form data structure
      await FirebaseFirestore.instance
          .collection("users")
          .doc(sellerId)
          .get()
          .then((DocumentSnapshot documentSnapshot) {
        // Get data from current user doc snapshot
        marketplaceId = documentSnapshot.get("marketplaceId");
        schoolId = documentSnapshot.get("schoolId");
      });

      // POTENTIAL PLACEHOLDER FOR TAG SETTING
      // NO proper item ID stored (empty string)

      // create userPost map for firebase document data
      final userPost = <String, dynamic>{
        "buyerId": "",
        "condition": formData["condition"],
        "dateDeleted": Timestamp(0, 0),
        "dateListed": Timestamp.now(),
        "dateUpdated": Timestamp(0, 0),
        "description": formData["description"],
        "images": formData["images"],
        "itemId": "",
        "marketplaceId": marketplaceId,
        "name": formData["title"],
        "price": double.parse(formData["price"]),
        "schoolId": schoolId,
        "sellerId": sellerId,
        "tags": []
      };

      // POTENTIAL PLACEHOLDER FOR UNACCEPTABLE STRING CHECKING (profanity, racism ...)

      // create post in db
      await FirebaseFirestore.instance.collection("items").doc().set(userPost);

      // show see post dialog upon successful creation
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Congratulations!'),
            content: Text('You have successfully created a post.'),
            actions: [
              TextButton(
                onPressed: () {
                  // Close the success dialog
                  Navigator.of(context).pop();
                  // Navigate to view post screen or any other logic
                  // For example, you can use Navigator.push to navigate to a new screen
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => ViewPostScreen()));
                },
                child: Text('Click here to view your post'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Show failure snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create post')),
      );
      throw ("failed async for create post");
    }
  }

  bool isValidPrice(String? value) {
    if (value == null) {
      return false;
    }

    // Regular expression to match a valid price format (e.g., 123.45)
    final RegExp priceRegex = RegExp(r'^\d+(\.\d{1,2})?$');
    return priceRegex.hasMatch(value);
  }
}

// Helper functions Converting XFile to String
Future<String> convertImageToDataUrl(XFile imageFile) async {
  List<int> imageBytes = await imageFile.readAsBytes();
  String dataUrl = 'data:image/${imageFile.name.split('.').last};base64,' +
      base64Encode(Uint8List.fromList(imageBytes));
  return dataUrl;
}

// Function for uploading selected post images to firebase
Future uploadImages(
    List<String> imageDataUrls, Completer<List<String>> completer) async {
  List<String> imageNames = [];
  // Create a firebase storage reference from app
  final storageRef = FirebaseStorage.instance.ref();

  await Future.forEach(imageDataUrls, (String dataUrl) async {
    // Extract image data from data URL
    Uint8List imageBytes = base64Decode(dataUrl.split(',').last);

    // Generate unique image reference in firebase image collection
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final imageRef = storageRef.child("images/$fileName.jpg");
    imageNames.add("images/$fileName.jpg");

    try {
      await imageRef.putData(imageBytes);
    } on FirebaseException catch (e) {
      // Undeveloped catch case for firebase write error
      print(e);
    }
  });

  completer.complete(imageNames);
}

Future<List<XFile>> multiImagePicker() async {
  List<XFile>? _images = await ImagePicker().pickMultiImage();
  if (_images.isNotEmpty && _images.length <= 3) {
    return _images;
  } else {
    print("Error: No images selected or more than 3 images selected!");
  }
  return [];
}

Future<List<String>> convertXFilesToDataUrls(List<XFile> xFiles) async {
  List<String> dataUrls = [];

  for (XFile xFile in xFiles) {
    String dataUrl = await convertImageToDataUrl(xFile);
    dataUrls.add(dataUrl);
  }

  return dataUrls;
}
