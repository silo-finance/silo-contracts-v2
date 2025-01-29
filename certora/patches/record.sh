#!/bin/bash

. ./certora/patches/files.sh
diff -uN $file1_origin $file1_munged | sed 's+\$file1_origin/++g' | sed 's+$file1_munged++g' > $patch1_path
# diff -uN $file2_origin $file2_munged | sed 's+\$file2_origin/++g' | sed 's+$file2_munged++g' > $patch_path2