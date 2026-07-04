#!/usr/bin/env bash
# jenkinsci/helm-charts init uses `yes n | cp -i` to copy plugins into EmptyDir
# /var/jenkins_plugins. On init container restart within the same pod, destination
# files already exist, cp prompts, `yes n` declines, and `set -e` exits 1.
# overwritePlugins only clears $JENKINS_HOME/plugins on PVC, not plugin-dir.
sed 's/yes n | cp -i/cp -f/g'
