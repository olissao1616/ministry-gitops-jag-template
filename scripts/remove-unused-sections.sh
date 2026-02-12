#!/bin/bash
# Remove unused chart sections (nginx, telnet, aspnet-core) from deploy values

set -e

DEPLOY_DIR="$(dirname "$0")/../deploy/{{cookiecutter.deploy_dir}}"

echo "Removing unused sections from deploy values..."

for file in dev_values.yaml test_values.yaml prod_values.yaml; do
    echo "Processing $file..."

    # Use Python to remove sections
    python3 - <<'EOF' "$DEPLOY_DIR/$file"
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Remove sections by finding them and the content until the next top-level key
# Top-level keys start at column 0 and end with ':'
sections_to_remove = ['nginx', 'telnet', 'aspnet-core']

lines = content.split('\n')
output_lines = []
skip_section = False
current_section = None

for line in lines:
    # Check if this is a top-level key (starts at column 0)
    if line and not line[0].isspace() and ':' in line:
        key = line.split(':')[0].strip()
        if key in sections_to_remove:
            skip_section = True
            current_section = key
            continue
        else:
            skip_section = False

    if not skip_section:
        output_lines.append(line)

# Write back
with open(file_path, 'w') as f:
    f.write('\n'.join(output_lines))

print(f"✓ Removed sections from {file_path}")
EOF

done

echo ""
echo "Done! Removed nginx, telnet, and aspnet-core sections."
