import re

def format_gemini_response(text: str) -> str:
    """
    Convert Gemini's markdown response to a more readable format for Flutter.
    - Converts ** bold ** to bold Unicode
    - Converts - bullet points to • bullets
    - Cleans up extra whitespace
    """
    # Convert **bold** to bold using Unicode bold characters
    def bold_text(match):
        text = match.group(1)
        # Convert to bold Unicode (mathematical alphanumeric symbols)
        bold_chars = ""
        for char in text:
            if char.isalpha():
                if char.isupper():
                    # Bold uppercase: U+1D400 + offset
                    bold_chars += chr(ord(char) - ord('A') + 0x1D400)
                else:
                    # Bold lowercase: U+1D41A + offset
                    bold_chars += chr(ord(char) - ord('a') + 0x1D41A)
            elif char.isdigit():
                # Bold digits: U+1D7CE + offset
                bold_chars += chr(ord(char) - ord('0') + 0x1D7CE)
            else:
                bold_chars += char
        return bold_chars
    
    # Replace **text** with bold version
    text = re.sub(r'\*\*(.+?)\*\*', bold_text, text)
    
    # Replace - bullets with • bullets
    text = re.sub(r'^- ', '• ', text, flags=re.MULTILINE)
    
    # Remove extra blank lines
    text = re.sub(r'\n\n+', '\n\n', text)
    
    return text.strip()