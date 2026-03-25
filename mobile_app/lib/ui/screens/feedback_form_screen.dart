import 'package:flutter/material.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('Feedback Form')), body: Center(child: Text('This is the feedback form screen.')));
  }
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
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
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter your feedback here',
              ),
            ),
            const SizedBox(height: 20),  
            CustomButton(
              text: 'Send Feedback',  
              onPressed: () {
                // Handle the button press (e.g., submit the form)
              },
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
      onPressed: _isPressed ? null : () {
        setState(() => _isPressed = true);
        widget.onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isPressed ? Colors.green : (widget.color ?? Theme.of(context).primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.0),
        ),
      ),
      child: _isPressed ? const SizedBox() : Text(
        widget.text,
        style: widget.textStyle ?? const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}