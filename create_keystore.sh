#!/bin/bash
# Script to create Android signing keystore for Plantry app

echo "=================================="
echo "Plantry - Create Release Keystore"
echo "=================================="
echo ""
echo "This script will create a keystore for signing your Android app."
echo "You'll be asked for passwords and company information."
echo ""
echo "⚠️  IMPORTANT: Save the passwords you enter! You'll need them forever!"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

KEYSTORE_PATH="$HOME/plantry-release-key.jks"
KEY_ALIAS="plantry-key-alias"

# Check if keystore already exists
if [ -f "$KEYSTORE_PATH" ]; then
    echo ""
    echo "❌ Keystore already exists at: $KEYSTORE_PATH"
    echo ""
    read -p "Do you want to OVERWRITE it? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled. Keystore not created."
        exit 0
    fi
    rm "$KEYSTORE_PATH"
fi

echo ""
echo "Creating keystore at: $KEYSTORE_PATH"
echo "Using alias: $KEY_ALIAS"
echo ""

# Create keystore
keytool -genkey -v \
  -keystore "$KEYSTORE_PATH" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$KEY_ALIAS"

# Check if successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Keystore created successfully!"
    echo ""
    echo "📝 Next steps:"
    echo "1. Create android/key.properties file:"
    echo "   cp android/key.properties.example android/key.properties"
    echo ""
    echo "2. Edit android/key.properties and fill in your passwords"
    echo ""
    echo "3. NEVER commit key.properties or .jks file to Git!"
    echo ""
    echo "4. Store both files in a SAFE location (backup drive, password manager)"
    echo ""
    echo "Keystore location: $KEYSTORE_PATH"
else
    echo ""
    echo "❌ Failed to create keystore"
    exit 1
fi
