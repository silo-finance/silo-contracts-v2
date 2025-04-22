FOUNDRY_PROFILE=core_test forge clean
FOUNDRY_PROFILE=core_test forge build --build-info

exit_code=$?

if [ $exit_code != 0 ]; then
  echo "build failed"
  exit $exit_code
fi
