import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uni_market/components/ItemGeneration/item.dart';
import 'package:uni_market/components/ItemGeneration/abstract_item_factory.dart';
import 'package:uni_market/helpers/filters.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:typesense/typesense.dart';

class ItemSearchBar extends StatefulWidget {
  // passing a function from the parent down so we can use its setState to redraw the items
  final Function(List<Widget> newItems, bool append) setPageState;
  final Function(String) updateSearchText;
  final Filters filter;

  // final Filters filters;

  // requiring the function
  const ItemSearchBar(
      {super.key,
      required this.setPageState,
      required this.updateSearchText,
      required this.filter});

  @override
  State<ItemSearchBar> createState() => _ItemSearchBarState();
}

class _ItemSearchBarState extends State<ItemSearchBar> {
  late FocusNode _focusNode;
  bool isDark = true;
  late String searchVal;
  final SearchController controller = SearchController();
  List<ListTile> suggestions = [];

  SearchPageController ctrl = SearchPageController();

  void updateSuggestions(String typedText) {
    setState(() {
      suggestions = List<ListTile>.generate(5, (int index) {
        final String item = '$typedText$index';
        return ListTile(
          title: Text(item),
          onTap: () {
            setState(() {
              // todo later: update the search function to include the now passed in filters using widget.filters
              ctrl.search(item, 30, context, widget.filter).then((value) {
                widget.setPageState(value, false);
              });
              controller.closeView(item);
            });
          },
        );
      });
    });
  }

  @override
  void initState() {
    _focusNode = FocusNode();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SearchAnchor(
          searchController: controller,
          // viewOnSubmited and viewOnChanged added via this PR: https://github.com/flutter/flutter/pull/136840, allows us to grab submitted and changed values
          viewOnSubmitted: (value) {
            // redraw the page when the search has been done
            ctrl.search(value, 30, context, widget.filter).then((value) {
              widget.setPageState(value, false);
            });
            controller.closeView(value);
          },
          viewOnChanged: (value) {
            updateSuggestions(value);
            widget.updateSearchText(value);
          },
          builder: (BuildContext context, controller) {
            // attempting to get the search bar to take an enter key to submit search
            return SearchBar(
              controller: controller,
              padding: const MaterialStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16.0)),
              onTap: () {
                controller.openView();
              },
              onChanged: (value) {
                if (!controller.isOpen) {
                  print(
                      value); // CURRENTLY EATS THIS BECAUSE IT HIGHLIGHTS THE TEXT ON TAP
                  controller.openView();
                  print(controller.value.text);
                }
              },
              leading: const Icon(Icons.search),
            );
          },
          suggestionsBuilder: (BuildContext context, controller) {
            return suggestions;
          }),
    );
  }
}

class SearchPageController {
  AbstractItemFactory factory = AbstractItemFactory();
  search(String searchTerm, int number, BuildContext context,
      Filters filter) async {
    List<Widget> widgets = [];
    final config = Configuration(
      'eSMjP8YVxHdMKoT164TTKLMkXRS47FdDnPENNAA2Ob8RfEfr',
      nodes: {
        Node(
          Protocol.https,
          "hawk-perfect-frog.ngrok-free.app",
          port: 443, // stuff provided by the cloud hosting
        ),
      },
      // numRetries: 3, // A total of 4 tries (1 original try + 3 retries)
      connectionTimeout: const Duration(seconds: 2),
    );

    final client = Client(config);

    String filterString = 'price:[${filter.lowerPrice}..${filter.upperPrice}]';

    String sort = '';

    switch (filter.sort) {
      case Sort.newestToOldest:
        sort = 'dateListed:desc';
        break;
      case Sort.oldestToNewest:
        sort = 'dateListed:asc';
        break;
      case Sort.highToLow:
        sort = 'price:desc';
        break;
      case Sort.lowToHigh:
        sort = 'price:asc';
        break;
      default:
        break;
    }

    switch (filter.condition) {
      case Condition.newItem:
        filterString += ' && condition:NEW';
        break;
      case Condition.usedItem:
        filterString += ' && condition:USED';
        break;
      case Condition.wornItem:
        filterString += ' && condition:WORN';
        break;
      case Condition.none:
        break;
    }

    final searchParameters = {
      'q': searchTerm,
      'query_by': 'embedding',
      'sort_by': sort,
      'filter_by': filterString,
    };
    final Map<String, dynamic> data =
        await client.collection('items').documents.search(searchParameters);
    if (context.mounted) {
      widgets = await generateItems(data, context);
    } else {
      if (kDebugMode) {
        print("no clue as to whats going on, buildcontext wasnt mounded");
      }
    }

    return widgets;
  }

  Future<String> getURL(
    String imageURL,
  ) async {
    String image;
    try {
      image = await FirebaseStorage.instance.ref(imageURL).getDownloadURL();
    } catch (e) {
      image = await FirebaseStorage.instance
          .ref("images/missing_image.jpg")
          .getDownloadURL();
    }
    return image;
  }

  generateItems(Map<String, dynamic> data, BuildContext context) async {
    List<Widget> widgets = [];
    for (var item in data['hits']) {
      if (item['document']['images'].length == 0) {
        item['document']['images'].add(await FirebaseStorage.instance
            .ref("images/missing_image.jpg")
            .getDownloadURL());
      } else {
        for (int i = 0; i < item['document']['images'].length; i++) {
          item['document']['images'][i] =
              await getURL(item['document']['images'][i]);
        }
      }

      if (context.mounted) {
        widgets.add(factory.buildItemBox(
            Item.fromJSON(item['document']), context)); // this is the issue
      }
    }
    return widgets;
  }
}
