#/bin/bash
comment=$1
hexo g -d
git add .
git commit -m "$1"
git push origin hexo
