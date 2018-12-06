#!/bin/bash

awk '{if(NR>1)print}' common.conf > temp_push.conf
cur_dir=`pwd`
module_list=""
branch=""
flag_merge="false"

while IFS="|"  read -r fDir fURL fBase;
do
dir_repo=`echo $fURL | awk -F '[/.]' '{print $(NF-1)}'`

repo_dir()
{
    if [[ $fDir = "" ]] || [[ $flag_dir == "invalid" ]]
      then
        echo "Codebase directory :"
        read fDir < /dev/tty
    fi
    if [[ ${#fDir} -eq 0 ]]
      then
        flag_dir="invalid"
        echo -e "ERROR : Invalid directory!\nPlease try again"
        repo_dir
    fi
    cd $fDir 2> /dev/null && flag_dir="valid" || flag_dir="invalid"
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


merge_branch()
{
    fNew=`git rev-parse --abbrev-ref @{-1}`
    echo "Merge branch - $fNew"
    if [[ $fNew = "" ]] || [[ $flag_new = "invalid" ]]
          then
            echo "Merge branch :"
            read fNew < /dev/tty
        fi
    validate $fNew && flag_new="valid" || flag_new="invalid"
    if [[ ${#fNew} -eq 0 ]]
      then
        flag_new="invalid"
    fi
    if [ $flag_new = "invalid" ]
          then
            echo -e "ERROR : Invalid merge branch!\nPlease try again"
            merge_branch
    else
        echo -e "WARNING : Please confirm if merge conflicts recorded for merging $fNew branch to $fBranch branch are manually resolved? \n\nFor Yes, Press 1\nFor No, Press 2\nFor Exit - Press 9"
        read fConflict < /dev/tty
        if [[ $fConflict = "1" ]]
          then
            echo -e "INFO : Merging $fNew branch to $fBranch branch"
            flag_merge="true"
        elif [[ $fConflict = "2" ]]
          then
            echo -e "EXIT !\nREASON : As confirmed, merge conflicts not resolved.\nRECOMMENDED : Resolve the conflicts manually and try git commit & push."
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        elif [[ $fConflict = "9" ]]
          then
            echo "Thank you!Have a nice day."
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        else
            echo -e "ERROR : Wrong input!\nPlease try again"
            list_of_files
        fi
    fi
}

list_of_files()
{
    status=$(git status)
    fBranch=`git rev-parse --abbrev-ref HEAD`
    
    validate $fBranch && flag_remote="valid" || flag_remote="invalid"
    
    if [[ $flag_remote == "invalid" ]]
      then
        echo -e "ERROR : Branch $fBranch is a local branch and not yet pushed to remote repository.\nRECOMMENDED : Please re-create the branch using Git Automation Tool."
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    fi
    
    local_commit=`git cherry -v origin/$fBranch | awk '{print $2}'`
    array_local=(${local_commit// / })
    length_local=${#array_local[@]}
    
    if [[ $flag_status != "true" ]]       
      then
        echo -e "\nInitiating code commit & push"
    fi
    
    if [[ $local_commit != "" ]] && [[ $flag_status != "true" ]]
      then
        echo -e "\nWARNING : Local unpushed Git commits available. Please find the details below:"
        for ((i=0;i<=$length_local-1;i++)); do
            local_status=`git diff-tree --no-commit-id --name-status -r ${array_local[$i]}`
            echo -e "\nCommit : ${array_local[$i]} \n$local_status"
        done
    fi

    if [[ $status == *"You have unmerged paths."* ]] || [[ $status == *"All conflicts fixed but you are still merging"* ]] && [[ $flag_status != "true" ]]
      then
        merge_branch
        fNew=`git rev-parse --abbrev-ref @{-1}`
        deleted_files1=`git status --porcelain | awk 'match($1, "UD"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        deleted_files2=`git status --porcelain | awk 'match($1, "DU"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        modified_files1=`git status --porcelain | awk 'match($1, "UU"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        added_files1=`git status --porcelain | awk 'match($1, "AA"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

        if [[ $deleted_files1 != "" ]]
          then
            echo -e "WARNING : Deleted $deleted_files1 from branch $fNew .\nDo you want to continue removing these files from $fBranch branch while merging $fNew branch? \n\nFor Yes, Press 1\nFor No, Press 2\nFor Exit - Press 9"
            read fDel < /dev/tty
            if [[ $fDel = "1" ]]
              then
                git rm $deleted_files1 &> /dev/null
                deleted_files+=" "$deleted_files1
                deleted_files1=""
            elif [[ $fDel = "2" ]]
              then
                echo -e "INFO : Not removing $deleted_files1 from $fBranch branch as requested."
            elif [[ $fDel = "9" ]]
              then
                echo "Thank you! Have a nice day."
                rm $cur_dir/temp_push.conf &> /dev/null
                rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
                rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
                rm -rf $cur_dir/$dir_track_repo &> /dev/null
                exit
            else
                echo -e "ERROR : Wrong input!\nPlease try again"
                list_of_files
            fi
        fi

        if [[ $deleted_files2 != "" ]]
          then
            echo -e "WARNING : Removed $deleted_files2 from branch $fBranch .\nDo you want to continue adding these files to $fBranch branch while merging $fNew branch? \n\nFor Yes, Press 1\nFor No, Press 2\nFor Exit - Press 9"
            read fDel1 < /dev/tty
            if [[ $fDel1 = "1" ]]
              then
                echo -e "INFO : Adding $deleted_files2 to $fBranch branch as requested."
                added_files+=" "$deleted_files2
            elif [[ $fDel1 = "2" ]]
              then
                git rm $deleted_files2 &> /dev/null
                deleted_files2=""
            elif [[ $fDel = "9" ]]
              then
                echo "Thank you! Have a nice day."
                rm $cur_dir/temp_push.conf &> /dev/null
                rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
                rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
                rm -rf $cur_dir/$dir_track_repo &> /dev/null
                exit
            else
                echo -e "ERROR : Wrong input!\nPlease try again"
                list_of_files
            fi
        fi

        staged_added_files=`git diff --name-status --staged | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        staged_modified_files=`git diff --name-status --staged | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        staged_deleted_files=`git diff --name-status --staged | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

        module_list="$deleted_files1"$'\n'"$deleted_files2"$'\n'"$modified_files1"$'\n'"$added_files1"
    else
        staged_files=`git diff --name-only --staged`
        if [[ $staged_files != "" ]]
          then
            staged_added_files=`git diff --name-status --staged | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            staged_modified_files=`git diff --name-status --staged | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            staged_deleted_files=`git diff --name-status --staged | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        fi

        unstaged_files=`git diff --name-only`
        if [[ $unstaged_files != "" ]]
          then
            unstaged_added_files=`git diff --name-status | awk 'match($1,"A") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            unstaged_modified_files=`git diff --name-status | awk 'match($1,"M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
            unstaged_deleted_files=`git diff --name-status | awk 'match($1,"D") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        fi

        untracked_files=`git ls-files --others --exclude-standard`
        if [[ $untracked_files != "" ]]
          then
            untracked_added_files=`git ls-files --others --exclude-standard -t | awk 'match($1,"/?") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
        fi

        module_list="$staged_files"$'\n'"$unstaged_files"$'\n'"$untracked_files"

        if [[ $staged_files = ""  &&  $unstaged_files = ""  && $untracked_files = "" ]]
          then
            if [[ $flag_status != "true" ]]
              then
                echo -e "\nBranch name : $fBranch \nINFO : Everything up-to-date with remote repository."
            fi
            if [[ $local_commit != "" ]]
              then
                flag_local_empty="true"
                echo -e "\nPress 1 to push all the local commits to remote repository\nPress 2 to Exit"
                read fLocalCommit < /dev/tty
                if [[ $fLocalCommit == "1" ]]
                  then
                    git_push $fBranch
                elif [[ $fLocalCommit == "2" ]]
                  then
                    echo -e "EXIT : Local unpushed Git commits not pushed to remote repository as requested."
                    rm $cur_dir/temp_push.conf &> /dev/null
                    rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
                    rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
                    rm -rf $cur_dir/$dir_track_repo &> /dev/null
                    exit
                else
                    echo -e "ERROR : Wrong input!\nPlease try again"
                    list_of_files
                fi 
            else
                rm $cur_dir/temp_push.conf &> /dev/null
                rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
                rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
                rm -rf $cur_dir/$dir_track_repo &> /dev/null
                exit
            fi
        fi
    fi
}


#dormant function
list_of_files1()
{
    status=$(git status)
    fBranch=`git rev-parse --abbrev-ref HEAD`
    echo -e "Branch name : $fBranch \nINFO : Initiating code commit & push"

    if [[ $status == *"You have unmerged paths."* ]] || [[ $status == *"All conflicts fixed but you are still merging"* ]]
      then
        merge_branch
    fi
    
    deleted_files=`git status --porcelain | awk '{if ($1 == "D") {print $2}}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    modified_files=`git status --porcelain | awk 'match($1, "M") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    added_files=`git status --porcelain | awk 'match($1, "/?") {print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

    deleted_files1=`git status --porcelain | awk 'match($1, "UD"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    deleted_files2=`git status --porcelain | awk 'match($1, "DU"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    modified_files1=`git status --porcelain | awk 'match($1, "UU"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    added_files1=`git status --porcelain | awk 'match($1, "AA"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`

    if [[ $deleted_files1 != "" ]]
      then
        echo -e "WARNING : Deleted $deleted_files1 from branch $fNew .\nDo you want to continue removing these files from $fBranch branch while merging $fNew branch? \n\nFor Yes, Press 1\nFor No, Press 2\nFor Exit - Press 9"
        read fDel < /dev/tty
        if [[ $fDel = "1" ]]
          then
            git rm $deleted_files1 &> /dev/null
            deleted_files+=" "$deleted_files1
            deleted_files1=""
        elif [[ $fDel = "2" ]]
          then
            echo -e "INFO : Not removing $deleted_files1 from $fBranch branch as requested."
        elif [[ $fDel = "9" ]]
          then
            echo "Thank you! Have a nice day."
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        else
            echo -e "ERROR : Wrong input!\nPlease try again"
            list_of_files
        fi
    fi

    if [[ $deleted_files2 != "" ]]
      then
        echo -e "WARNING : Removed $deleted_files2 from branch $fBranch .\nDo you want to continue adding these files to $fBranch branch while merging $fNew branch? \n\nFor Yes, Press 1\nFor No, Press 2\nFor Exit - Press 9"
        read fDel1 < /dev/tty
        if [[ $fDel1 = "1" ]]
          then
            echo -e "INFO : Adding $deleted_files2 to $fBranch branch as requested."
            added_files+=" "$deleted_files2
        elif [[ $fDel1 = "2" ]]
          then
            git rm $deleted_files2 &> /dev/null
            deleted_files2=""
        elif [[ $fDel = "9" ]]
          then
            echo "Thank you! Have a nice day."
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        else
            echo -e "ERROR : Wrong input!\nPlease try again"
            list_of_files
        fi
    fi    
    
    if [[ $deleted_files = "" ]] && [[ $modified_files = "" ]] && [[ $added_files = "" ]]
      then
        echo -e "EXIT !\nREASON : Everything up-to-date with remote repository."
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    else 
        echo -e "*********************************************************\nList of changed files (Deleted/Modified/Added)\n*********************************************************"
        if [[ $deleted_files != "" ]] || [[ $deleted_files1 != "" ]] || [[ $deleted_files2 != "" ]]
          then
            echo -e "\nDeleted : $deleted_files $deleted_files1 $deleted_files2"
        else
            echo -e "\nDeleted: -"
        fi
        if [[ $modified_files != "" ]] || [[ $modified_files1 != "" ]]
          then
            echo -e "Modified : $modified_files $modified_files1" 
        else
            echo -e "Modified: -"
        fi
        if [[ $added_files != "" ]] || [[ $added_files1 != "" ]]
          then
            echo -e "Added: $added_files $added_files1"
        else
            echo -e "Added: -"
        fi
        echo -e "\n*********************************************************"
    fi
    if [[ $flag_merge = "true" ]]
      then
        module_list="$deleted_files1"$'\n'"$deleted_files2"$'\n'"$modified_files1"$'\n'"$added_files1"$'\n'"$deleted_files"$'\n'"$modified_files"$'\n'"$added_files"
    else
        module_list="$deleted_files"$'\n'"${modified_files}"$'\n'"${added_files}"
    fi
}

validate()
{
    git branch -r > $cur_dir/branches.txt
    awk '{gsub(/origin\//,"\n")}1' $cur_dir/branches.txt > $cur_dir/branches1.txt
    cat $cur_dir/branches1.txt | grep -Fxq "$1";
}

download_tracker()
{
    awk '{if(NR>1)print}' $cur_dir/tracker.conf > $cur_dir/temp_tracker.conf
    while IFS="|"  read -r fTrack_URL tracker_path ;
    do
        if [[ $fTrack_URL = "" ]] || [[ $flag_tracker = "invalid" ]]
          then
            echo "Repo URL for tracker:"
            read fTrack_URL < /dev/tty
        fi
        if [[ ${#fTrack_URL} -eq 0 ]]
          then
            flag_tracker="invalid"
            echo -e "ERROR : Invalid URL for tracker!\nPlease try again"
            download_tracker
        fi
        cd $cur_dir
        git clone $fTrack_URL &> /dev/null
        dir_track_repo=`echo $fTrack_URL | awk -F '[/.]' '{print $(NF-1)}'`
        cd $dir_track_repo &> /dev/null && flag_tracker="valid" || flag_tracker="invalid"
        if [ $flag_tracker == "invalid" ]
          then
            echo -e "ERROR : Invalid URL : $fTrack_URL  for tracker!\nPlease try again"
            download_tracker
        fi

        if [[ $flag_tracker_dir == "invalid" ]]
          then
            echo -e "Directory for tracker :"
            read tracker_path < /dev/tty
        fi

        if [[ $tracker_path != "" ]]
          then
            tracker_path_dir=$tracker_path/
            cd $tracker_path_dir &> /dev/null && flag_tracker_dir="valid" || flag_tracker_dir="invalid"
            cd -
        else
            flag_tracker_dir="valid"
            tracker_path_dir=""
        fi

        if [[ $flag_tracker_dir == "invalid" ]]
          then
            echo -e "ERROR : Invalid directory for tracker!\nPlease try again"
            download_tracker
        fi

        git fetch &> /dev/null
        git checkout origin/master -- $tracker_path_dir${dir_repo}_tracker.csv &> /dev/null && flag_repo_tracker="valid" || flag_repo_tracker="invalid"
        if [ $flag_repo_tracker == "invalid" ]
          then
            echo -e "WARNING : ${dir_repo}_tracker.csv file is not available in remote repository.\nCreating new ${dir_repo}_tracker.csv file."
        else
            mv $tracker_path_dir${dir_repo}_tracker.csv $cur_dir/
            git reset HEAD $tracker_path_dir${dir_repo}_tracker.csv &> /dev/null
        fi
    done < $cur_dir/temp_tracker.conf
    rm $cur_dir/temp_tracker.conf &> /dev/null
}


git_add()
{
    fBranch=`git rev-parse --abbrev-ref HEAD`
    fProd_branch=`awk 'BEGIN {FS = ", "}; {if ($7 == "In-Production") {print $3}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    live=`awk -v var1=$fBranch 'BEGIN {FS = ", "}; {if ($13 == var1) {print $13}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    updated_username=`git config user.name`
    
    [[ $live =~ (^|[[:space:]])"$fBranch"($|[[:space:]]) ]] && flag_live="true" || flag_live="false"
    [[ $fProd_branch =~ (^|[[:space:]])"$fBranch"($|[[:space:]]) ]] && flag_prod="true" || flag_prod="false"
    
    if [[ $flag_live = "true" && $flag_merge = "true" ]]
      then
        sys_owner=`awk -v var1=$fNew 'BEGIN {FS = ", "}; {if ($3 == var1) {print $8}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    elif [[ $flag_prod = "true" ]]
      then
        sys_owner=`awk -v var1=$fBranch 'BEGIN {FS = ", "}; {if ($3 == var1) {print $8}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    else
        sys_owner=`awk -v var1=$fBranch 'BEGIN {FS = ", "};  {print $8}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    fi

    [[ $sys_owner =~ (^|[[:space:]])"$updated_username"($|[[:space:]]) ]] && flag_user="true" || flag_user="false"
    
    if [[ $flag_live = "true" && $flag_merge = "false" ]]
      then
        echo -e "EXIT !\nREASON : Code push (Direct) to $fBranch branch is not allowed as this is a live / production branch.\nRECOMMENDED : Please consult your system owner."
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    elif [[ $flag_live = "true" && $flag_user = "false" ]]
      then
        echo -e "EXIT !\nREASON : Code push (Merge conflict) to $fBranch branch is not allowed as this is a live / production branch.\nRECOMMENDED : Please consult your system owner."
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    elif [[ $flag_live = "true" && $flag_user = "true" && $flag_merge = "true" ]]
      then
        echo -e "WARNING : System owner have permission to code push (Merge conflict) to $fBranch branch as this is a live / production branch.\nDo you want to continue? \n\nFor Yes, Press 1\nFor No and Exit, Press 2"
        read fPermission < /dev/tty
        if [[ $fPermission = "1" ]]
          then
            echo
        elif [[ $fPermission = "2" ]]
          then
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        else
            echo -e "ERROR : Wrong input!\nPlease try again."
            git_add
        fi
    fi
    
    if [[ $flag_prod = "true" && $flag_user = "false" ]]
      then
        echo -e "EXIT !\nREASON : $fBranch branch is already in production and no more changes to this branch will be acknowledged.\nRECOMMENDED : Please consult your system owner."
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    elif  [[ $flag_prod = "true" && $flag_user = "true" ]]
      then
        echo -e "WARNING : $fBranch branch is deployed in production. System owner have permission to code push to $fBranch branch.\nDo you want to continue? \n\nFor Yes, Press 1\nFor No and Exit, Press 2"
        read fPermission1 < /dev/tty
        if [[ $fPermission1 = "1" ]]
          then
            echo
        elif [[ $fPermission1 = "2" ]]
          then
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        else
            echo -e "ERROR : Wrong input!\nPlease try again."
            git_add
        fi
    fi
    cd $cur_dir
    ./git_status.sh
    flag_status="true"
    cd $fDir$dir_repo
    list_of_files
    module_list=$module_list | awk -v RS="" '{gsub (/\n/," ")}1'
    if [[ $module_list != "" ]] && [[ $flag_merge = "true" || $unstaged_files != "" || $untracked_files != "" ]]
      then
        echo -e "Do you want to stage(add) all the unstaged/untracked files? \n\nFor Yes, Press 1\nFor No, Press 2\nFor Exit - Press 9"
        read fFile < /dev/tty
        if [[ $fFile = "1" ]]
          then
            git add $module_list &> /dev/null
        elif [[ $fFile = "2" ]]
          then
            echo -e "Please specify the file names to be staged below (space separated)"
            read module_list  < /dev/tty
            if [[ $module_list == "" ]]
              then
                echo -e "ERROR : Input can't be empty!\nPlease try again"
                git_add
            else
                git add $module_list &> /dev/null
            fi
        elif [[ $fFile = "9" ]]
          then
            echo "Thank you! Have a nice day"
            rm $cur_dir/temp_push.conf &> /dev/null
            rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
            rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
            rm -rf $cur_dir/$dir_track_repo &> /dev/null
            exit
        else
            echo -e "ERROR : Wrong input!\nPlease try again"
            git_add
        fi  
    fi
    if [[ $flag_merge = "true" ]]
      then
        module_list="$deleted_files1"$'\n'"$deleted_files2"$'\n'"$modified_files1"$'\n'"$added_files1"$'\n'"$staged_added_files"$'\n'"$staged_modified_files"$'\n'"$staged_deleted_files" 
    fi
}

git_commit()
{
    echo -e "List of files added / staged :" $module_list | awk -v RS="" '{gsub (/\n/," ")}1' 
    echo -e "Do you want to commit the staged files? \n\nFor Yes, Press 1\nFor No & Exit, Press 2"
    read commit_decision < /dev/tty 
    if [[ $commit_decision == "1" ]]
      then
        if [[ $flag_merge = "true" ]]
          then
            git commit --no-edit &> /dev/null
        else
            printf "Commit message :\n"
            read fCommit < /dev/tty
            if [[ ${#fCommit} -eq 0 ]]
              then
                echo -e "ERROR : Commit message cannot be empty!\nPlease try again."
                git_commit
            fi
            git commit -m "$fCommit" &> /dev/null
        fi
    elif [[ $commit_decision == "2" ]]
      then
        echo -e "Exiting as requested. Changes to be committed: " $module_list | awk -v RS="" '{gsub (/\n/," ")}1'
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    else
        echo -e "ERROR : Wrong input!\nPlease try again"
        git_commit
    fi

}

git_push_decide()
{
    fBranch=`git rev-parse --abbrev-ref HEAD`
    echo -e "SUCCESS!\nINFO : Git add & commit successful for $fBranch branch BUT not yet pushed to remote repository!\nDo you want to push the changes to remote repository? \n\nFor Yes, Press 1\nFor No & Exit, Press 2"
    read fPush < /dev/tty
    if [[ $fPush = "1" ]]
      then
        git_push $fBranch
    elif [[ $fPush = "2" ]]
      then
        echo -e "EXIT !\nREASON : Code push to remote repository is stopped as requested. Changes are committed locally in $fDir$dir_repo directory"
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit
    else
        echo -e "ERROR : Wrong input!\nPlease try again"
        git_push_decide 
    fi
}

git_push()
{
    retries=3
    while ((retries > 0)); do
        if git push origin $1 &> /dev/null ; then
            branch=`echo $1`
            if [[ $flag_tracker_push = "true" ]]
              then
                echo -e "INFO : Updated ${dir_repo}_tracker.csv" 
            else
                echo -e "SUCCESS!\nINFO : Changes pushed to remote $branch branch!"
            fi
            break
        else
            echo -e "ERROR : Code push failed! Wrong git credentials!"
            sleep 2
            ((retries --))
        fi
    done
    if ((retries == 0 )); then
        echo -e "EXIT!\nREASON : Maximum 3 re-attempts allowed."
        rm $cur_dir/temp_push.conf &> /dev/null
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        rm $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        rm -rf $cur_dir/$dir_track_repo &> /dev/null
        exit 1
    fi
}

tracker_update ()
{       
    commit=`git rev-parse --verify $branch`
    remote_del=`git diff --name-status HEAD@{1} HEAD@{0} | awk 'match($1, "D"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    remote_mod=`git diff --name-status HEAD@{1} HEAD@{0} | awk 'match($1, "M"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    remote_add=`git diff --name-status HEAD@{1} HEAD@{0} | awk 'match($1, "A"){print $2}' | awk -v RS="" '{gsub (/\n/," ")}1'`
    updated_email=`git config user.email`
    updated_username=`git config user.name`
    
    if [[ $flag_merge = "true" ]]
      then
        if [[ $flag_live = "true" ]]
          then
            `awk -v var1=$branch -v var2=" $remote_del" -v var3=" $remote_mod" -v var4=" $remote_add" -v var5=$commit -v var6=$updated_email -v var7=$updated_username -v var8="$(date "+%Y-%m-%d %H:%M:%S")" -v var9=$fNew 'BEGIN {FS = ", "} {OFS = ", "}; {if ($3 == var9) {$6 = $6 "  Merge Commit (" var9 " -> " var1 ") - Id: " var5 " - Deleted : " var2 " Modified : " var3 " Added : " var4; $7 = "In-Production"; $10 = var7; $11 = var6; $12 = var8};  print}' $cur_dir/${dir_repo}_tracker.csv >> $cur_dir/${dir_repo}_tracker1.csv` &> /dev/null
            mv $cur_dir/${dir_repo}_tracker1.csv $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        else
            `awk -v var1=$branch -v var2=" $remote_del" -v var3=" $remote_mod" -v var4=" $remote_add" -v var5=$commit -v var6=$updated_email -v var7=$updated_username -v var8="$(date "+%Y-%m-%d %H:%M:%S")" -v var9=$fNew 'BEGIN {FS = ", "} {OFS = ", "}; {if ($3 == var1) {$6 = $6 "  Merge Commit (" var9 " -> " var1 ") - Id: " var5 " - Deleted : " var2 " Modified : " var3 " Added : " var4; $7 = "Active"; $10 = var7; $11 = var6; $12 = var8};  print}' $cur_dir/${dir_repo}_tracker.csv >> $cur_dir/${dir_repo}_tracker1.csv` &> /dev/null
            mv $cur_dir/${dir_repo}_tracker1.csv $cur_dir/${dir_repo}_tracker.csv &> /dev/null
        fi
    else
        `awk -v var1=$branch -v var2=" $remote_del" -v var3=" $remote_mod" -v var4=" $remote_add" -v var5=$commit -v var6=$updated_email -v var7="$updated_username" -v var8="$(date "+%Y-%m-%d %H:%M:%S")" 'BEGIN {FS = ", "} {OFS = ", "}; {if ($3 == var1) {$6 = $6 "  Commit Id : " var5 " - Deleted : " var2 " Modified : " var3 " Added : " var4; $7 = "Active"; $10 = var7; $11 = var6; $12 = var8};  print}' $cur_dir/${dir_repo}_tracker.csv >> $cur_dir/${dir_repo}_tracker1.csv` &> /dev/null
        mv $cur_dir/${dir_repo}_tracker1.csv $cur_dir/${dir_repo}_tracker.csv &> /dev/null
    fi
}

automerge ()
{
    awk '{if(NR>1)print}' automerge.conf > temp_automerge.conf
    branch_list=`awk  'BEGIN {FS = "|"}; {print}' < $cur_dir/temp_automerge.conf | awk -v RS="|" '1'`
    ar=($branch_list)
    [[ $branch_list =~ (^|[[:space:]])"$fBranch"($|[[:space:]]) ]] && automerge_branch="true" || automerge_branch="false"
    if [[ $automerge_branch = "true" ]]
      then
        index=1; for i in "${ar[@]}"; do
            [[ $i == "$fBranch" ]] && break
            ((++index))
        done
        export index
        cd $cur_dir
        ./git_automerge.sh
    else
        echo -e "INFO : Automerge not initiated for $fBranch branch.\nRECOMMENDED : Mention the sequence of deployment for $fBranch branch in automerge.conf to initiate automerge."
    fi
    rm $cur_dir/temp_automerge.conf &> /dev/null
}

rebase_email ()
{       
    sys_owner_email=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($3 == var1) {print $9}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'` 
    if [[ $flag_merge = "true" ]]
      then
        rebase_user=`awk -v var1=$branch -v var2=$fNew -v var3="In-Production" 'BEGIN {FS = ", "}; {if ($2 == var1 && $3 != var2 && $7 != var3) {print $4}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
        rebase_email_id=`awk -v var1=$branch -v var2=$fNew -v var3="In-Production" 'BEGIN {FS = ", "}; {if ($2 == var1 && $3 != var2 && $7 != var3) {print $5}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
        rebase_branch=`awk -v var1=$branch -v var2=$fNew -v var3="In-Production" 'BEGIN {FS = ", "}; {if ($2 == var1 && $3 != var2 && $7 != var3) {print $3}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    else
        rebase_user=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($2 == var1) {print $4}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
        rebase_email_id=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($2 == var1) {print $5}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
        rebase_branch=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($2 == var1) {print $3}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
    fi
    if [[ $flag_live = "true" ]]
      then
        email=`git config user.email`
        username=`git config user.name`
        date=$(date "+%Y-%m-%d %H:%M:%S")
    else
        username=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($3 == var1) {print $10}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
        email=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($3 == var1) {print $11}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/\n/," ")}1'`
        date=`awk -v var1=$branch 'BEGIN {FS = ", "}; {if ($3 == var1) {print $12}}' $cur_dir/${dir_repo}_tracker.csv | awk -v RS="" '{gsub (/" "/,"")}1'`
    fi
    if [[ $rebase_user != "" ]] && [[ $rebase_email_id != "" ]] && [[ $rebase_branch != "" ]]
      then
        array1=(${rebase_user// / })
        array2=(${rebase_email_id// / })
        array3=(${rebase_branch// / })
        length=${#array1[@]}
            
        for ((i=0;i<=$length-1;i++)); do
            echo -e "Hi ${array1[$i]},\n\nBranch ${array3[$i]} created by you is baselined to $branch branch. Changes are made to $branch branch by $username ($email) for commit id: $commit at $date . \nThe list of changed files is as below: \n\nDeleted: $remote_del \nModified: $remote_mod \nAdded: $remote_add \n\nPlease rebaseline your ${array3[$i]} branch to $branch branch. \n\n\nRegards,\nErlang L3 \nEmail ID: erlang_l3@thbs.com" | mailx -s "Rebaseline branch - ${array3[$i]} to $branch branch" -c $sys_owner_email ${array2[$i]}
        done
    fi
    if [[ $flag_merge = "true" ]]
      then
        echo -e "Hi $username , \n\nYou have successfully merged $fNew branch into $branch branch for commit id: $commit at $date .\nThe list of changed files is as below: \n\nDeleted: $remote_del \nModified: $remote_mod \nAdded: $remote_add \n\n\nRegards,\nErlang L3 \nEmail ID: erlang_l3@thbs.com" | mailx -s "Merge successful - $fNew branch into $branch branch" -c $sys_owner_email $email
    fi
}
#git config --global credential.helper 'cache --timeout=900'
download_tracker
repo_dir
repo_clone
list_of_files
if [[ $flag_local_empty != "true" ]]
  then
    git_add
    git_commit
    git_push_decide
fi
tracker_update
rebase_email

cd $cur_dir/$dir_track_repo
if [[ $tracker_path_dir != "" ]]
  then
    mv $cur_dir/${dir_repo}_tracker.csv $tracker_path_dir &> /dev/null
else
    mv $cur_dir/${dir_repo}_tracker.csv . &> /dev/null
fi

git add $tracker_path_dir${dir_repo}_tracker.csv &> /dev/null
if [[ $flag_merge = "true" ]]
  then
    git commit -m "Merged $fNew branch into $branch branch" &> /dev/null
else
    git commit -m "Code push to $branch branch" &> /dev/null
fi
flag_tracker_push="true"
git_push master
cd ..
rm -rf $cur_dir/$dir_track_repo &> /dev/null
rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
done < temp_push.conf
rm $cur_dir/temp_push.conf &> /dev/null

if [[ $FLAG_AUTOMERGE = "true" ]]
  then
    automerge
fi
