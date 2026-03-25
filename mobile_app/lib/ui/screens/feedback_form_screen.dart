import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    final feedbackText = _feedbackController.text.trim();
    if (feedbackText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter feedback before sending.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.feedbackUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'feedback': feedbackText,
              'user_id': '',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _feedbackController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback sent successfully!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to send feedback: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error sending feedback: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Feedback'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('What feedback do you have?'),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your feedback here',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: _isSubmitting ? 'Sending...' : 'Send Feedback',
              onPressed: _isSubmitting ? () {} : _sendFeedback,
              color: _isSubmitting ? Colors.grey : null,
            ),
          ],
        ),
      ),
    );
  }
}

class FraudWidget extends StatefulWidget {
  const FraudWidget({super.key});

  @override
  State<FraudWidget> createState() => _FraudWidgetState();
}

class _FraudWidgetState extends State<FraudWidget> {
  bool sentMessage = false;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final double? borderRadius;
  final TextStyle? textStyle;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.color,
    this.borderRadius,
    this.textStyle,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isPressed
          ? null
          : () {
              setState(() => _isPressed = true);
              widget.onPressed();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isPressed
            ? Colors.green
            : (widget.color ?? Theme.of(context).primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.0),
        ),
      ),
      child: _isPressed
          ? const SizedBox()
          : Text(
              widget.text,
              style: widget.textStyle ??
                  const TextStyle(color: Colors.white, fontSize: 16),
            ),
    );
  }
}
