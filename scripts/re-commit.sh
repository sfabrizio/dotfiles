export datesam=$2 && export commitsam=$1 && git filter-branch -f --env-filter \
    'if [ $GIT_COMMIT == $commitsam ] ; then
	     export GIT_AUTHOR_DATE="$datesam"
         export GIT_COMMITER_DATE="$datesam"
     fi'
