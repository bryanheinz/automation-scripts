#!/bin/sh

# autopkg automation script which, when run with no arguments, checks current run's output against a default output and sends the output to a user if there are differences

# adjust the following variables for your particular configuration
# you should manually run the script with the initialize option if you change the recipe list, since that will change the output.
recipe_list=""
mail_recipient="tickets@example.com"
autopkg_user="autopkg"

# define file locations
# folder path to store autopkg-wrapper files
autopkg_wrapper_dir="/opt/autopkg/automation-scripts"
# text file with a list of recipes (easier than the above recipe_list)
recipe_list_file="${autopkg_wrapper_dir}/recipe_list.txt"
# persistent file path to store AutoPkg output for diffing
autopkg_output_file="${autopkg_wrapper_dir}/autopkg.out"
# temporary file path to store AutoPkg output for diffing
autopkg_tmp_file="/private/tmp/autopkg.out"

emailer="${autopkg_wrapper_dir}/autopkg/emailer.py"

# don't change anything below this line

# define logger behavior
logger="/usr/bin/logger -t autopkg-wrapper"
user_home_dir=$(dscl . -read /Users/${autopkg_user} NFSHomeDirectory | awk '{ print $2 }')

# run autopkg
if [ "${1}" == "help" ]; then
    # show some help with regards to initialization option
    echo "usage: ${0} [initialize]"
    echo "(initializes a new default log for notification checking)"
    exit 0
elif [ "${1}" == "initialize" ]; then
    # initialize default log for automated run to check against for notification if things have changed
    $logger "starting autopkg to initialize a new default output log"
    
    # make sure autopkg folder exists in autopkg_user's Documents folder
    if [ ! -d "${autopkg_wrapper_dir}" ]; then
        /bin/mkdir -p "${autopkg_wrapper_dir}"
    fi
    
    # make sure recipe list file exists
    if [ ! -f "${recipe_list_file}" ]; then
        echo "MakeCatalogs.munki" >> "${recipe_list_file}"
    fi
    
    # read the recipe list file
    recipe_list_contents=$(cat "${recipe_list_file}")
    # combine the recipe list file with the hard-coded recipe list
    recipe_list="${recipe_list} ${recipe_list_contents}"
    
    echo "recipe list: ${recipe_list}"
    echo "autopkg user: ${autopkg_user}"
    echo "user home dir: ${user_home_dir}"
    
    # run autopkg twice, once to get any updates and the second to get a log indicating nothing changed
    $logger "autopkg initial run to temporary log location"
    echo "for this autopkg run, output will be shown"
    /usr/local/bin/autopkg run -v ${recipe_list} 2>&1
    
    $logger "autopkg initial run to saved log location"
    echo "for this autopkg run, output will not be shown, but rather saved to default log location (${autopkg_output_file})"
    /usr/local/bin/autopkg run ${recipe_list} 2>&1 > "${autopkg_output_file}"
    
    $logger "finished autopkg"
elif [ ! -f "${autopkg_output_file}" ]; then
    # default log doesn't exist, so tell user to run this script in initialization mode and exit
    echo "ERROR: default log does not exist, please run this script with initialize argument to initialize the log"
    exit -1
elif [ ! -f "${recipe_list_file}" ]; then
    # default recipe doesn't exist, so tell user to run this script in initialization mode and exit
        echo "ERROR: default recipe list does not exist, please run this script with initialize argument to initialize the recipe list"
        exit -1
else
    # default is to just run autopkg and email log if something changed from normal
    
    # read the recipe list file
    recipe_list_contents=$(cat "${recipe_list_file}")
    # combine the recipe list file with the hard-coded recipe list
    recipe_list="${recipe_list} ${recipe_list_contents}"
    
    $logger "starting autopkg"
    echo "starting autopkg"
    /usr/local/bin/autopkg repo-update all
    /usr/local/bin/autopkg run ${recipe_list} 2>&1 > ${autopkg_tmp_file}
    
    $logger "finished autopkg"
    echo "finished autopkg"
    
    # check output against the saved log and if differences exist, send current log to specified recipient
    log_diff=$(diff "$autopkg_tmp_file" "$autopkg_output_file")
    if [ "$log_diff" != "" ]; then
        echo "emailing log."
        # there are differences from a "Nothing downloaded, packaged or imported" run... might be an update or an error
        $logger "sending autopkg log"
        # email the log using a custom Python SMTP email script.
        python3 $emailer
        $logger "sent autopkg log to {$mail_recipient}, $(wc -l "$autopkg_tmp_file" | awk '{ print $1 }') lines in log"
    else
        echo "not emailing log."
        $logger "autopkg did nothing, so not sending log"
    fi
fi
exit 0
