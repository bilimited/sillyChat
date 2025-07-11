import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';
import '../../providers/character_controller.dart';

class CharacterSelector extends StatefulWidget {
  final List<CharacterModel>? excludeCharacters;

  const CharacterSelector({
    Key? key,
    this.excludeCharacters,
  }) : super(key: key);

  @override
  State<CharacterSelector> createState() => _CharacterSelectorState();
}

class _CharacterSelectorState extends State<CharacterSelector> {
  final searchController = TextEditingController();
  final searchText = ''.obs;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characterController = Get.find<CharacterController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('选择角色'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '搜索角色...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onChanged: (value) => searchText.value = value,
            ),
          ),
          Expanded(
            child: Obx(() {
              final availableCharacters = characterController.characters
                  .where((char) => !(widget.excludeCharacters
                          ?.any((excluded) => excluded.id == char.id) ??
                      false))
                  .where((char) => char.roleName
                      .toLowerCase()
                      .contains(searchText.value.toLowerCase()))
                  .toList();

              final groupedCharacters = <String, List<CharacterModel>>{};
              for (var char in availableCharacters) {
                if (!groupedCharacters.containsKey(char.category)) {
                  groupedCharacters[char.category] = [];
                }
                groupedCharacters[char.category]!.add(char);
              }

              return ListView.builder(
                itemCount: groupedCharacters.length,
                itemBuilder: (context, index) {
                  final category = groupedCharacters.keys.elementAt(index);
                  final characters = groupedCharacters[category]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: SillyChatApp.isDesktop() ? 5 : 4,
                          childAspectRatio: 0.8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: characters.length,
                        itemBuilder: (context, charIndex) {
                          final char = characters[charIndex];
                          return InkWell(
                            onTap: () => Get.back(result: char),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.file(
                                      File(char.avatar),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.8),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 8,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: Text(
                                        char.roleName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 16),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
