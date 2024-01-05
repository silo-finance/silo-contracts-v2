#!/usr/bin/env bash

# Directory containing the files
directory_path="silo-core/contracts/lib"

# Word replacement
old_word1="external"
new_word1="internal /*ori_ext*/"
new_word1_escaped=$(printf '%s\n' "$new_word1" | sed -e 's/[]\/$*.^[]/\\&/g')

old_word2="public"
new_word2="internal /*ori_pub*/"
new_word2_escaped=$(printf '%s\n' "$new_word2" | sed -e 's/[]\/$*.^[]/\\&/g')

# Loop through each file in the directory
for file in "$directory_path"/*; do
    if [ -f "$file" ]; then
        echo "Modified file: $file"
        # Perform word replacement in each file
        sed -i '' "s@$old_word1@$new_word1_escaped@g" $file
        sed -i '' "s@$old_word2@$new_word2_escaped@g" $file
    fi
done
