#!/bin/bash -e

[ "$DEBUG_BOOTING" == 'true' ] && set -x

SCRIPTS_DIR="`dirname "$(realpath "$0")"`"

START_SCRIPT='
  concurrently                             \
      -p "[{name}]"                        \
      -n "Lint,Hint,Hardhat,DocGen"        \
      -c "green.bold,blue.bold,cyan.bold"  \
      "npm run lint"                       \
      "npm run hint"                       \
      "npm run build"                      \
      "npm run docgen"                     \
  '

if [ "$WATCH_FILES" = "true" ]; then

  echo -e "\x1b[33mWatching and running start script\x1b[0m"

  chokidar                       \
    test/**                      \
    scripts/**                   \
    contracts/**                 \
    hardhat.config.js            \
    -c "$START_SCRIPT"           \
    --debounce 500               \
    --initial                    \
    --silent

else

  echo -e "\x1b[33mRunning start script\x1b[0m"

  sh -c "$START_SCRIPT"

fi
