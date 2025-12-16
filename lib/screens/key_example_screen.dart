import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Example Screen for EmojiPicker using EmojiPickerUtils with Key
class KeyExampleScreen extends StatefulWidget {
  const KeyExampleScreen({super.key});

  @override
  KeyExampleScreenState createState() => KeyExampleScreenState();
}

class KeyExampleScreenState extends State<KeyExampleScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _emojiShowing = false;

  // 1. Create GlobalKey for EmojiPickerState
  final key = GlobalKey<EmojiPickerState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Key Example'),
      ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: ElevatedButton(
                  child: const Text('Clear Recent Emoji'),
                  onPressed: () {
                    // 3. Clear Recent Emoji List
                    EmojiPickerUtils().clearRecentEmojis(key: key);
                  },
                ),
              ),
            ),
            _buildTextInputField(),
            Offstage(
              offstage: !_emojiShowing,
              child: SizedBox(
                height: 250,
                child: EmojiPicker(
                  // 2. Set global key here
                  key: key,
                  textEditingController: _controller,
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildTextInputField() {
    return Container(
      height: 66.0,
      color: Colors.blue,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: IconButton(
              onPressed: () {
                setState(() {
                  _emojiShowing = !_emojiShowing;
                });
              },
              icon: const Icon(
                Icons.emoji_emotions,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 20.0, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.only(
                        left: 16.0, bottom: 8.0, top: 8.0, right: 16.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                  )),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: IconButton(
              onPressed: () {
                // send message
              },
              icon: const Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
