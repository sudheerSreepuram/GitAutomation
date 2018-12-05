#!/bin/bash

welcome()
{
echo -e "*************************************************************************************************************************************\n****************************************************Welcome to Git Automation Tool***************************************************\n*************************************************************************************************************************************\n\nFeel free to post your suggestions or defects, if any, to sourav_ghatak@thbs.com/sourav.ghatak@ee.co.uk\n\nPlease specify the operation you would like to perform.\n\nPress 1 for Git Clone and/or Git Checkout       (Note : Update common.conf for cloning a git repository and/or checking out a branch)\nPress 2 for Git Status                          (Note : Update common.conf for checking the git status of the local git repository)\nPress 3 for New Git Branch Creation             (Note : Update common.conf and sys_owner.conf to initiate new branch creation)\nPress 4 for Git merge                           (Note : Update merge.conf to initiate git merge)\nPress 5 for Git Commit & Push                   (Note : Update common.conf to initiate git commit & push)\nPress 6 for Git Automerge                       (Note : Update automerge.conf & merge.conf to initiate git automerge)\nPress 7 for Code Healthcheck                    (Note : Update automerge.conf & merge.conf to initiate code healthcheck)\nPress 8 for Exit"
read fMaster

if [[ $fMaster == "1" ]]
  then
    ./git_clone.sh
elif [[ $fMaster == "2" ]]
  then
    ./git_status.sh
elif [[ $fMaster == "3" ]]
  then
    ./git_create.sh
elif [[ $fMaster == "4" ]]
  then
    ./git_merge.sh
elif [[ $fMaster == "5" ]]
  then
    ./git_push.sh
elif [[ $fMaster == "6" ]]
  then
    export direct_automerge="true"
    export index=1
    ./git_automerge.sh
elif [[ $fMaster == "7" ]]
  then
    export healthcheck="true"
    export index=1
    ./git_healthcheck.sh
elif [[ $fMaster == "8" ]]
  then
    echo "Thanks! Have a nice day"
else
    echo "Wrong input! Please try again"
    welcome
fi
}

welcome
