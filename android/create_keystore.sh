#!/bin/bash

# Keystore Creation Script for Plantry Android App
# This script creates a release keystore for signing your Android app

set -e

echo "=========================================="
echo "Plantry - Android Keystore Generator"
echo "=========================================="
echo ""

# Configuration
KEYSTORE_FILE="app/keystore.jks"
KEY_ALIAS="plantry-release-key"
VALIDITY_DAYS=10000

# Check if keystore already exists
if [ -f "$KEYSTORE_FILE" ]; then
    echo "ERROR: Keystore file already exists at $KEYSTORE_FILE"
    echo "To create a new keystore, first backup and delete the existing one."
    exit 1
fi

echo "This script will create a release keystore for your Android app."
echo "You will need to provide:"
echo "  - Keystore password (min 6 characters)"
echo "  - Key password (min 6 characters)"
echo "  - Your name"
echo "  - Organization name"
echo "  - City/Locality"
echo "  - State/Province"
echo "  - Country code (2 letters, e.g., DE)"
echo ""
echo "IMPORTANT: Store these passwords securely!"
echo "If you lose the keystore or passwords, you cannot update your app!"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Prompt for passwords
echo ""
read -sp "Enter keystore password (min 6 chars): " KEYSTORE_PASSWORD
echo ""
read -sp "Confirm keystore password: " KEYSTORE_PASSWORD_CONFIRM
echo ""

if [ "$KEYSTORE_PASSWORD" != "$KEYSTORE_PASSWORD_CONFIRM" ]; then
    echo "ERROR: Passwords do not match!"
    exit 1
fi

if [ ${#KEYSTORE_PASSWORD} -lt 6 ]; then
    echo "ERROR: Password must be at least 6 characters!"
    exit 1
fi

read -sp "Enter key password (min 6 chars): " KEY_PASSWORD
echo ""
read -sp "Confirm key password: " KEY_PASSWORD_CONFIRM
echo ""

if [ "$KEY_PASSWORD" != "$KEY_PASSWORD_CONFIRM" ]; then
    echo "ERROR: Passwords do not match!"
    exit 1
fi

if [ ${#KEY_PASSWORD} -lt 6 ]; then
    echo "ERROR: Password must be at least 6 characters!"
    exit 1
fi

# Prompt for certificate information
echo ""
echo "Certificate Information:"
read -p "Your name: " DNAME_CN
read -p "Organization name (e.g., Plantry): " DNAME_O
read -p "City/Locality: " DNAME_L
read -p "State/Province: " DNAME_ST
read -p "Country code (2 letters, e.g., DE): " DNAME_C

# Construct DN
DNAME="CN=$DNAME_CN, O=$DNAME_O, L=$DNAME_L, ST=$DNAME_ST, C=$DNAME_C"

echo ""
echo "Generating keystore..."
echo ""

# Generate keystore
keytool -genkey \
    -v \
    -keystore "$KEYSTORE_FILE" \
    -keyalg RSA \
    -keysize 2048 \
    -validity $VALIDITY_DAYS \
    -alias "$KEY_ALIAS" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "$DNAME"

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to generate keystore!"
    exit 1
fi

# Create key.properties file
echo ""
echo "Creating key.properties file..."

cat > key.properties << EOF
storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=keystore.jks
EOF

echo ""
echo "=========================================="
echo "SUCCESS! Keystore created successfully!"
echo "=========================================="
echo ""
echo "Files created:"
echo "  - $KEYSTORE_FILE (your signing key)"
echo "  - key.properties (configuration file)"
echo ""
echo "IMPORTANT - NEXT STEPS:"
echo ""
echo "1. BACKUP the keystore file to a safe location!"
echo "   cp $KEYSTORE_FILE ~/keystore-backup-$(date +%Y%m%d).jks"
echo ""
echo "2. SAVE your passwords in a password manager:"
echo "   Keystore Password: (the password you just entered)"
echo "   Key Password: (the password you just entered)"
echo ""
echo "3. NEVER commit key.properties or keystore.jks to git!"
echo "   (Already in .gitignore)"
echo ""
echo "4. Test your release build:"
echo "   cd .."
echo "   flutter build appbundle --release"
echo ""
echo "WARNING: If you lose this keystore or passwords,"
echo "you will NEVER be able to update your app in Play Store!"
echo ""
