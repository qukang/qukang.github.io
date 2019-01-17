#/bin/bash
comment=$1
if [ "$comment" != "" ];
then
 hexo g -d
 git add .
 git commit -m "$1"
 git push origin hexo
else
 echo "comment cannot be null!"
fi
