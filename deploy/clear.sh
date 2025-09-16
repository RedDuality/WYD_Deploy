#!/bin/bash
set -e

# Resolve this script's directory so it works no matter where it's run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ask_and_run() {
  local dir="$1"
  local script="clear.sh"

  echo
  read -r -p "Do you want to clear ${dir}? (y/N): " choice
  choice="${choice,,}"  # to lowercase

  if [[ "$choice" == "y" || "$choice" == "yes" ]]; then
    if [[ -d "$SCRIPT_DIR/$dir" ]]; then
      if [[ -f "$SCRIPT_DIR/$dir/$script" ]]; then
        chmod +x "$SCRIPT_DIR/$dir/$script"
        echo "⏳ Running ${dir}/${script}..."
        # Run in a subshell so directory changes don't leak, and don't abort on failure
        if ( cd "$SCRIPT_DIR/$dir" && bash "./$script" ); then
          echo "✅ ${dir} cleared."
        else
          echo "⚠️ ${dir}/${script} exited with an error. Continuing."
        fi
      else
        echo "⚠️ No ${script} found in ${dir}."
      fi
    else
      echo "⚠️ Directory ${dir} not found."
    fi
  else
    echo "⏭ Skipping ${dir}."
  fi
}

ask_and_run "blobstorage"
ask_and_run "rest-server"
ask_and_run "ingress"

echo
echo "🎯 Cleanup process finished."
