#!/bin/bash
# Script to replace postgresql-ha with simple postgresql in deploy values files

set -e

DEPLOY_DIR="$(dirname "$0")/../deploy/{{cookiecutter.deploy_dir}}"

echo "Replacing postgresql-ha with simple postgresql..."

# New postgresql configuration to insert
read -r -d '' NEW_POSTGRESQL << 'EOF' || true
# Simple PostgreSQL database
# NOTE: For production, consider using a managed database service
postgresql:
  enabled: false
  auth:
    username: appuser
    password: changeme  # Change this in production!
    database: appdb
  image:
    pullPolicy: Always
  primary:
    podSecurityContext:
      enabled: false
    containerSecurityContext:
      enabled: false
    persistence:
      enabled: true
      size: 256Mi
    resources:
      limits:
        cpu: 50m
        memory: 256Mi
      requests:
        cpu: 20m
        memory: 100Mi
    initdb:
      scripts:
        01_init_schema.sql: |
          -- Sample schema for testing
          CREATE TABLE IF NOT EXISTS public.users (
              id SERIAL PRIMARY KEY,
              username VARCHAR(255) UNIQUE NOT NULL,
              email VARCHAR(255),
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          );

          CREATE TABLE IF NOT EXISTS public.sessions (
              id SERIAL PRIMARY KEY,
              user_id INTEGER REFERENCES users(id),
              token VARCHAR(255),
              expires_at TIMESTAMP
          );

          -- Insert sample data
          INSERT INTO public.users (username, email) VALUES
          ('admin', 'admin@example.com'),
          ('user1', 'user1@example.com'),
          ('user2', 'user2@example.com')
          ON CONFLICT (username) DO NOTHING;
  commonLabels:
    environment: ENVIRONMENT_PLACEHOLDER
    env: ENVIRONMENT_PLACEHOLDER
    owner: "{{cookiecutter.team_name}}"
    project: "{{cookiecutter.project_name}}"
    DataClass: "Medium"
    app.kubernetes.io/part-of: "{{cookiecutter.project_name}}"
  commonAnnotations:
    datree.skip/CUSTOM_WORKLOAD_INCORRECT_NETWORKS: "skipping this policy"
EOF

# Process each file
for file in "test_values.yaml" "prod_values.yaml"; do
    echo "Processing $file..."

    # Determine environment
    if [[ "$file" == "test_values.yaml" ]]; then
        ENV="test"
    else
        ENV="prod"
    fi

    # Create temp file with new content
    TEMP_CONTENT=$(echo "$NEW_POSTGRESQL" | sed "s/ENVIRONMENT_PLACEHOLDER/$ENV/g")

    # Delete postgresql-ha section and insert new postgresql section
    awk -v new_content="$TEMP_CONTENT" '
        BEGIN { in_section=0; printed=0 }
        /^postgresql-ha:/ { in_section=1; if (!printed) { print new_content; print ""; printed=1 } next }
        in_section && /^[a-z]/ { in_section=0 }
        !in_section { print }
    ' "$DEPLOY_DIR/$file" > "$DEPLOY_DIR/$file.tmp"

    mv "$DEPLOY_DIR/$file.tmp" "$DEPLOY_DIR/$file"

    echo "✓ Updated $file"
done

echo ""
echo "Done! postgresql-ha replaced with simple postgresql in test and prod values files."
