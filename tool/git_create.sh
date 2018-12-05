#!/bin/bash
awk '{if(NR>1)print}' common.conf > temp_create.conf
cur_dir="$PWD"
email=`git config user.email`
username=`git config user.name`
while IFS="|"  read -r fDir fURL;
do
dir_repo=""
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

base_branch()
{
    echo "Base branch :"
    read fBase < /dev/tty
    validate $fBase && flag="valid" || flag="invalid"
    if [[ ${#fBase} -eq 0 ]]
      then
        flag="invalid"
    fi
    if [ $flag = "valid" ]
      then
        git fetch &> /dev/null
        git checkout $fBase &> /dev/null
        git pull origin $fBase &> /dev/null
    else
        echo -e "ERROR : Invalid base branch.\nPlease try again!"
        base_branch
    fi
}

live_branch()
{
    echo "Live/Production branch :"
    read live < /dev/tty
    validate $live && flag_live="valid" || flag_live="invalid"
    if [[ ${#live} -eq 0 ]]
      then
        flag_live="invalid"
    fi
    if [ $flag_live != "valid" ]
      then
        echo -e "ERROR : Invalid live branch.\nPlease try again!"
        live_branch
    fi
}

new_branch()
{
    echo "New branch :"
    read fNew < /dev/tty
    validate $fNew && flag_new="valid" || flag_new="invalid"
    if [[ ${#fNew} -eq 0 ]]
      then
        flag_new="valid"
    fi
    if [ $flag_new = "invalid" ]
      then
        echo
    else
        echo -e "ERROR : Branch $fNew already exists or invalid branch name.\nPlease provide a different branch name and try again"
        new_branch
    fi
}

code_push()
{
    retries=3
    while ((retries > 0)); do
        git push origin $1 &> /dev/null && break 
        echo -e "ERROR : Code push failed! Wrong git credentials!"
        sleep 2
        ((retries --))
    done
    if ((retries == 0 )); then
        echo -e "EXIT!\nREASON : Maximum 3 re-attempts allowed."
        rm $cur_dir/temp_create.conf &> /dev/null
        rm -rf $cur_dir/$dir_track_repo
        rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
        exit 1
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
            echo -e "ERROR : Invalid URL : $fTrack_URL for tracker!\nPlease try again"
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

tracker_update ()
{
    download_tracker
    if [ ! -f $cur_dir/${dir_repo}_tracker.csv ]
      then
        echo "Repository name","Base Branch","New Branch","Created By","Branch Owner's Email address","Commit Id & Changed files, Status", "System Owner Git username", "System Owner's Email address", "Last Updated By", "Last Updated Email address", "Last Updated time", "Live Branch" > excel_header
        paste -sd, excel_header >> $cur_dir/${dir_repo}_tracker.csv && rm excel_header
    fi
    date=`date "+%Y-%m-%d %H:%M:%S"`

    echo $dir_repo, $fBase, $fNew, $username, $email, , "Active", $fOwner, $fOwner_email, $username, $email, $date, $live > excel_convert
    paste -sd, excel_convert >> $cur_dir/${dir_repo}_tracker.csv && rm excel_convert

    git checkout master &> /dev/null
    if [[ $tracker_path_dir != "" ]]
      then
        mv $cur_dir/${dir_repo}_tracker.csv $tracker_path_dir &> /dev/null
    else
        mv $cur_dir/${dir_repo}_tracker.csv . &> /dev/null
    fi
    git add $tracker_path_dir${dir_repo}_tracker.csv &> /dev/null
    git commit -m "Created new branch : $fNew" &> /dev/null
    echo -e "INFO : Updated ${dir_repo}_tracker.csv"
    code_push master
    cd ..
    rm -rf $cur_dir/$dir_track_repo
    rm $cur_dir/branches.txt $cur_dir/branches1.txt &> /dev/null
}

echo -e "Initiating new branch creation"

repo_dir
repo_clone
base_branch
new_branch
live_branch

fOwner=`awk -v var1=$dir_repo 'BEGIN {FS = "|"}; {if ($1 == var1) {print $2}}' $cur_dir/sys_owner.conf`
fOwner_email=`awk -v var1=$dir_repo 'BEGIN {FS = "|"}; {if ($1 == var1) {print $3}}' $cur_dir/sys_owner.conf`

echo -e "INFO : Review the details provided for new branch creation\n***********************************************************************************************\nDirectory for local codebase : $fDir \nBase branch : $fBase \nNew Branch : $fNew \nURL (Git repository URL) : $fURL \nSystem Owner's Git Username : $fOwner \nSystem Owner's email : $fOwner_email \nProduction Branch : $live \n***********************************************************************************************\n\nDo you want to continue creating a new branch $fNew - baselined to $fBase branch? \n\nFor Yes - Press 1\nFor No & Exit - Press 2"
read fResp < /dev/tty
if [[ $fResp = "1" ]]
  then
    #git config --global credential.helper 'cache --timeout=900'
    git checkout -b $fNew &> /dev/null
    code_push $fNew && tracker_update
    echo -e "SUCCESS!\nINFO : New branch : $fNew created successfully and baselined to : $fBase branch"
elif [[ $fResp = "2" ]]
  then
    echo -e "EXIT !\nREASON : Branch creation stopped as requested.\nRECOMMENDED : Update create.conf with the required inputs and try again"
else
    echo -e "ERROR : Wrong input.\nPlease try again."
    ./git_create.sh
fi
done < temp_create.conf
rm $cur_dir/temp_create.conf &> /dev/null
