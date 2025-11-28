#!/bin/bash

echo "Watching for changes in src/ and test/..."
echo "Press Ctrl+C to stop."
echo ""

gleam test

fswatch -o src/ test/ | while read; do
  clear
  echo "Change detected, running tests..."
  gleam test
done
