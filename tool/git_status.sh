#!/bin/bash

awk '{if(NR>1)print}' common.conf > temp_clone.conf

cur_dir=`pwd`
while IFS="|"  read -r fDir fURL fBase;
do

repo_dir()
{
    if [[ $fDir = "" ]] || [[ $flag_dir == "invalid" ]]
      then
        echo "Codebase directory : "
        read fDir < /dev/tty
    fi
    if [[ ${#fDir} -eq 0 ]]
      then
        flag_dir="invalid"
        echo -e "ERROR : Invalid directory!\nPlease try again"
        repo_dir
    fi
    cd $fDir &> /dev/null && flag_dir="valid" || flag_dir="invalid"
    if [ $flag_dir == "invalid" ]
      then
        echo -e "ERROR : Invalid directory!\nPlease try again"
        repo_dir
    fi
}

repo_clone()
{
    if [[ $fURL = "" ]] || [[ $flag_repo = "invalid" ]]
      then
        echo "Repo URL :"
        read fURL < /dev/tty
    fi
    if [[ ${#fURL} -eq 0 ]]
      then
        flag_repo="invalid"
        echo -e "ERROR : Invalid URL!\nPlease try again"
        repo_clone
    fi
    git clone $fURL &> /dev/null
    dir_repo=`echo $fURL | awk -F '[/.]' '{print $(NF-1)}'`
    cd $dir_repo &> /dev/null && flag_repo="valid" || flag_repo="invalid"
    if [ $flag_repo == "invalid" ]
      then
        echo -e "ERROR : Invalid URL!\nPlease try again"
        repo_clone
    fi
}

validate()
{
    git branch -r > $cur_dir/branches.txt
    awk '{gsub(/origin\//,"\n")}1' $cur_dir/branches.txt > $cur_dir/branches1.txt
    cat $cur_dir/branches1.txt | grep -Fxq "$1";
}

list_of_files()
{
    status=$(git status)
    fBranch=`git rev-parse --abbrev-ref HEAD`
    echo -e "\nBranch name : $fBranch"
    validate $fBranch && flag_remote="valid" || flag_remote="invalid"

    if [[ $status == *"You have unmerged paths."* ]]
      then
        flag_merge="true"
        fNew=`git rev-parse --abbrev-ref @{-1}`
        deleted_files1=`git status --porcelain | awk 'match($1, "UD"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        deleted_files2=`git status --porcelain | awk 'match($1, "DU"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        modified_files1=`git status --porcelain | awk 'match($1, "UU"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        added_files1=`git status --porcelain | awk 'match($1, "AA"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
       
        echo -e "\nINFO : You have unmerged paths while merging $fNew branch to $fBranch branch. \nRECOMMENDED : Resolve conflicts manually and do 'Git Commit & Push' from Git Automation Tool\n"
       
        staged_added_files=`git diff --name-status --staged | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        staged_modified_files=`git diff --name-status --staged | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        staged_deleted_files=`git diff --name-status --staged | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
 
        if [[ $staged_added_files != "" ]] || [[ $staged_modified_files != "" ]] || [[ $staged_deleted_files != "" ]]
          then
            echo -e "*********************************************************\nStaged files - Changes to be committed\n*********************************************************"
            staged_added_files=`git diff --name-status --staged | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            staged_modified_files=`git diff --name-status --staged | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            staged_deleted_files=`git diff --name-status --staged | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

            if [[ $staged_added_files != "" ]]
              then
                echo -e "Added : $staged_added_files"
            fi
            if [[ $staged_modified_files != "" ]]
              then
                echo -e "Modified : $staged_modified_files"
            fi
            if [[ $staged_deleted_files != "" ]]
              then
                echo -e "Deleted : $staged_deleted_files"
            fi
        fi
        echo -e "\n*********************************************************\nUnmerged paths - Conflicted files\n*********************************************************"

        if [[ $deleted_files1 != "" ]]
          then
            echo -e "Deleted by $fNew branch : $deleted_files1 \n(Details : Removing $deleted_files1 from $fBranch branch while merging $fNew branch)\n"
        fi
        if [[ $deleted_files2 != "" ]]
          then
            echo -e "Deleted by $fBranch branch : $deleted_files2 \n(Details : Adding  $deleted_files2 to $fBranch branch while merging $fNew branch)\n"
        fi
        if [[ $modified_files1 != "" ]]
          then
            echo -e "Modified by both : $modified_files1 \n(Details : Modified $modified_files1 by both $fBranch branch and $fNew branch)\n"
        fi
        if [[ $added_files1 != "" ]]
          then
            echo -e "Added by both : $added_files1 \n(Details : Added $added_files1 by both $fBranch branch and $fNew branch)\n"
        fi
        echo -e "\n(Note : Use Git commit & Push from main menu to mark resolution)"
        echo -e "*********************************************************" 
    else    
        staged_files=`git diff --name-only --staged`
        if [[ $staged_files != "" ]]
          then
            echo -e "\n*********************************************************\nStaged files - Changes to be committed\n*********************************************************"
            staged_added_files=`git diff --name-status --staged | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            staged_modified_files=`git diff --name-status --staged | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            staged_deleted_files=`git diff --name-status --staged | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

            if [[ $staged_added_files != "" ]]
              then
                echo -e "Added : $staged_added_files"
            fi
            if [[ $staged_modified_files != "" ]]
              then
                echo -e "Modified : $staged_modified_files"
            fi
            if [[ $staged_deleted_files != "" ]]
              then
                echo -e "Deleted : $staged_deleted_files"
            fi
            echo -e "\n(Note : To unstage the staged files - Press 1)"
        fi

        unstaged_files=`git diff --name-only`
        if [[ $unstaged_files != "" ]]
          then
            echo -e "\n*********************************************************\nUnstaged files - Changes not staged for commit\n*********************************************************"
            unstaged_added_files=`git diff --name-status | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            unstaged_modified_files=`git diff --name-status | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            unstaged_deleted_files=`git diff --name-status | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

            if [[ $unstaged_added_files != "" ]]
              then
                echo -e "Added : $unstaged_added_files"
            fi
            if [[ $unstaged_modified_files != "" ]]
              then
                echo -e "Modified : $unstaged_modified_files"
            fi
            if [[ $unstaged_deleted_files != "" ]]
              then
                echo -e "Deleted : $unstaged_deleted_files"
            fi
            echo -e "\n(Note : To discard the changes in working directory - Press 2)"
        fi

        untracked_files=`git ls-files --others --exclude-standard`
        if [[ $untracked_files != "" ]]
          then
            echo -e "\n*********************************************************\nUntracked files\n*********************************************************"
            untracked_added_files=`git ls-files --others --exclude-standard -t | awk 'match($1,"/?") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            echo -e "Added : $untracked_added_files"
            echo -e "\n(Note : Use Git commit & Push from main menu to include what will be committed)"
        fi

        if [[ $flag_remote == "invalid" ]]
          then
            echo -e "\nEXIT : Branch $fBranch is a local branch and not yet pushed to remote repository.\nRECOMMENDED : Please re-create the branch using Git Automation Tool."
            rm $cur_dir/temp_clone.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            exit
        fi

        if [[ $staged_files = "" ]] && [[ $unstaged_files = "" ]] && [[ $untracked_files = "" ]]
          then
            echo -e "INFO : Nothing to commit, working directory clean."
            rm $cur_dir/temp_clone.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            exit
        fi

        echo -e "\n*********************************************************"
    fi
}

discard ()
{
    echo -e "Unstage the staged files - Press 1\nDiscard the changes in working directory - Press 2\nNo Changes required - Press 3"
    read fInput < /dev/tty
    if [[ $fInput == "1" ]]
      then
        if [[ $staged_files == "" ]]
          then
            echo -e "\nERROR : No staged files. Please re-try\n"
            discard
        fi
        echo -e "Changes to be committed - " $staged_files | awk -v RS="" '{gsub (/\n/," ")}1'
        echo -e "Specify the files to be unstaged (space separated)"
        read fStaged < /dev/tty
        if [[ $fStaged == "" ]]
          then
            echo -e "\nERROR : Input can't be empty\n"
            discard
        fi
        array1=(${fStaged// / })
        length=${#array1[@]}
        for ((i=0;i<=$length-1;i++)); do
            [[ $staged_files =~ (^|[[:space:]])${array1[$i]}($|[[:space:]]) ]] && flag_staged="true" || flag_staged="false"
            if [[ $flag_staged == "true" ]]
              then
                git reset HEAD ${array1[$i]} &> /dev/null
            else
                echo -e "\nERROR : Wrong input - ${array1[$i]} is not staged\n"
            fi
        done
        list_of_files
        discard
    elif [[ $fInput == "2" ]]
      then
        if [[ $unstaged_files == "" ]]
          then
            echo -e "\nERROR : No unstaged changes. Please re-try\n"
            discard
        fi
        echo -e "Changes not staged for commit - " $unstaged_files | awk -v RS="" '{gsub (/\n/," ")}1'
        echo -e "Specify the files for which changes to be discarded (space separated)"
        read fUnstaged < /dev/tty
        if [[ $fUnstaged == "" ]]
          then
            echo -e "\nERROR : Input can't be empty\n"
            discard
        fi
        array2=(${fUnstaged// / })
        length=${#array2[@]}
        for ((i=0;i<=$length-1;i++)); do
            [[ $unstaged_files =~ (^|[[:space:]])${array2[$i]}($|[[:space:]]) ]] && flag_unstaged="true" || flag_unstaged="false"
            if [[ $flag_unstaged == "true" ]]
              then
                git checkout -- ${array2[$i]} &> /dev/null
            else
                echo -e "\nERROR : Wrong input - ${array2[$i]} is not unstaged\n"
            fi
        done
        list_of_files
        discard
    elif [[ $fInput == "3" ]]
      then
        echo -e "\nNo changes made. Use Git commit & Push from main menu to update or include what will be committed"
        rm $cur_dir/temp_clone.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        exit
    else
        echo -e "ERROR : Wrong input!\nPlease try again"
        discard
    fi
}
repo_dir
repo_clone
list_of_files
if [[ $flag_merge != "true" ]]
  then
    discard
fi
done < temp_clone.conf
rm $cur_dir/temp_clone.conf &> /dev/null
rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
