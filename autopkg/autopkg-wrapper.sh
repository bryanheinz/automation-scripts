#!/usr/bin/env zsh

# autopkg automation script which, when run with no arguments, checks current run's output against a default output and sends the output to a user if there are differences

# adjust the following variables for your particular configuration
# you should manually run the script with the initialize option if you change the recipe list, since that will change the output.
mail_to="tickets@example.com"
mail_from="autopkg@example.com"

# define file locations
# folder path to store autopkg-wrapper files (the root folder for this script)
autopkg_wrapper_root="/opt/autopkg/automation-scripts"
# folder path to store custom autopkg-wrapper files
autopkg_wrapper_custom="${autopkg_wrapper_root}/custom"
# text file with a list of recipes (easier than the above recipe_list)
recipe_list_file="${autopkg_wrapper_custom}/recipe_list.txt"
# persistent file path to store AutoPkg output for diffing
autopkg_output_file="${autopkg_wrapper_custom}/autopkg.out"
# temporary file path to store AutoPkg output for diffing
autopkg_tmp_file="/private/tmp/autopkg.out"
# script path for emailing the results
emailer="${autopkg_wrapper_root}/autopkg/emailer.py"

# don't change anything below this line #

# loosely logged in case there's a problem. won't survive reboots, but also
# don't have to manage logging storage
logger () {
    echo "$1"
    echo "$(date +"%Y-%m-%dT%H:%M:%S%z") $1" >> /private/tmp/autopkg_wrapper.log
}


# make sure autopkg wrapper custom folders exist
if [[ ! -d "$autopkg_wrapper_custom" ]]; then
    /bin/mkdir -p "$autopkg_wrapper_custom"
fi

# run autopkg
if [[ "${1}" == "help" ]]; then
    # show some help with regards to initialization option
    echo "usage: ${0} [initialize]"
    echo "(initializes a new default log for notification checking)"
    exit 0
elif [[ "${1}" == "initialize" ]]; then
    # initialize default log for automated run to check against for notification
    # if things have changed
    logger "starting autopkg to initialize a new default output log"
    
    # make sure recipe list file exists
    if [[ ! -f "${recipe_list_file}" ]]; then
        echo "MakeCatalogs.munki" >> "${recipe_list_file}"
    fi
    
    echo "recipe list: $(cat $recipe_list_file)"
    
    # run autopkg twice, once to get any updates and the second to get a log
    # indicating nothing changed
    logger "autopkg initial run to temporary log location"
    logger "for this autopkg run, output will be shown"
    /usr/local/bin/autopkg run -v --recipe-list "$recipe_list_file" 2>&1
    
    logger "autopkg initial run to saved log location"
    logger "for this autopkg run, output will not be shown, but rather saved to default log location (${autopkg_output_file})"
    /usr/local/bin/autopkg run --recipe-list "$recipe_list_file" \
        2>&1 > "${autopkg_output_file}"
    
    logger "finished autopkg"
elif [[ ! -f "${autopkg_output_file}" ]]; then
    # default log doesn't exist, so tell user to run this script in
    # initialization mode and exit
    logger "ERROR: default log does not exist, please run this script with initialize argument to initialize the log"
    exit 1
elif [[ ! -f "${recipe_list_file}" ]]; then
    # default recipe doesn't exist, so tell user to run this script in initialization mode and exit
    logger "ERROR: default recipe list does not exist, please run this script with initialize argument to initialize the recipe list"
    exit 1
else
    # default is to just run autopkg and email log if something changed from normal
    
    logger "starting autopkg"
    /usr/local/bin/autopkg repo-update all
    /usr/local/bin/autopkg run --recipe-list "$recipe_list_file" \
        2>&1 > ${autopkg_tmp_file}
    
    logger "finished autopkg"
    
    # check output against the saved log and if differences exist, send current
    # log to specified recipient
    log_diff=$(/usr/bin/diff "$autopkg_tmp_file" "$autopkg_output_file")
    if [[ "$log_diff" != "" ]]; then
        # there are differences from a "Nothing downloaded, packaged or
        # imported" run... might be an update or an error
        logger "emailing autopkg log"
        # email the log using a custom Python SMTP email script.
        # arg1 == TO address, arg2 == FROM address
        python3 $emailer $mail_to $mail_from
        logger "sent autopkg log to ${mail_to}, $(/usr/bin/wc -l "$autopkg_tmp_file" | /usr/bin/awk '{ print $1 }') lines in log"
    else
        logger "no autopkg updates. not sending a log."
    fi
fi
exit 0
