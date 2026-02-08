#!/bin/bash
# =============================================
# Plantry - Version Update Script
# =============================================
#
# Usage: ./update_version.sh <version> <build>
# Example: ./update_version.sh 0.8.8 13
#
# This script updates:
# - pubspec.yaml
# - lib/utils/app_version.dart
# - README.md
#
# =============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check if correct number of arguments
if [ "$#" -ne 2 ]; then
    print_error "Wrong number of arguments!"
    echo ""
    echo "Usage: ./update_version.sh <version> <build>"
    echo "Example: ./update_version.sh 0.8.8 13"
    echo ""
    echo "Arguments:"
    echo "  version: Semantic version (MAJOR.MINOR.PATCH)"
    echo "  build:   Build number (must be incrementing)"
    exit 1
fi

VERSION=$1
BUILD=$2
FULL_VERSION="${VERSION}+${BUILD}"

# Validate version format (semantic versioning)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format: $VERSION"
    echo "Expected format: MAJOR.MINOR.PATCH (e.g., 0.8.8)"
    exit 1
fi

# Validate build number
if ! [[ $BUILD =~ ^[0-9]+$ ]]; then
    print_error "Invalid build number: $BUILD"
    echo "Expected: Positive integer (e.g., 13)"
    exit 1
fi

echo ""
print_info "Updating Plantry to version ${FULL_VERSION}"
echo ""

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
print_info "Current version: ${CURRENT_VERSION}"
print_info "New version:     ${FULL_VERSION}"
echo ""

# Confirm with user
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Aborted by user"
    exit 0
fi

echo ""

# 1. Update pubspec.yaml
print_info "Updating pubspec.yaml..."
sed -i "s/^version: .*/version: ${FULL_VERSION}/" pubspec.yaml
print_success "pubspec.yaml updated"

# 2. Update lib/utils/app_version.dart
print_info "Updating lib/utils/app_version.dart..."
sed -i "s/static const String version = '.*';/static const String version = '${FULL_VERSION}';/" lib/utils/app_version.dart
print_success "lib/utils/app_version.dart updated"

# 3. Update README.md
print_info "Updating README.md..."
sed -i "0,/\*\*Version:\*\* [0-9.+]*/{s/\*\*Version:\*\* [0-9.+]*/\*\*Version:\*\* ${VERSION}/}" README.md
sed -i "0,/- \*\*Version:\*\* [0-9.+]*/{s/- \*\*Version:\*\* [0-9.+]*/- \*\*Version:\*\* ${VERSION}/}" README.md
print_success "README.md updated"

echo ""
print_success "All files updated successfully!"
echo ""

# Show diff
print_info "Changes made:"
echo ""
git diff --color pubspec.yaml lib/utils/app_version.dart README.md || true

echo ""
print_info "Next steps:"
echo "  1. Update CHANGELOG.md with release notes"
echo "  2. Review changes: git diff"
echo "  3. Test build: flutter build apk --release"
echo "  4. Commit: git add . && git commit -m 'Release v${VERSION}'"
echo "  5. Tag: git tag v${VERSION}"
echo "  6. Push: git push origin master --tags"
echo ""
