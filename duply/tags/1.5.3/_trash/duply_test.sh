#!/bin/bash
#
###############################################################################
#  duply (formerly known as ftplicity), a shell front end to duplicity that   #
#  simplifies the usage by managing settings for each backup job in profiles. #
#  It supports executing multiple commands in a batch mode to enable single   #
#  line cron entries and allows the user to use pre/post backup scripts.      #
#  Since version 1.5.0 all duplicity backends are supported. Hence the name   #
#  changed from ftplicity to duply.                                           #
#  See http://duply.net or http://ftplicity.sourceforge.net/ for more info.   #
#  (c) 2006 Christiane Ruetten, Heise Zeitschriften Verlag, Germany           #
#  (c) 2008-2009 Edgar Soldin (changes since version 1.3)                     #
###############################################################################
#  LICENSE:                                                                   #
#  This program is licensed under GPLv2.                                      #
#  Please read the accompanying license information in gpl.txt.               #
###############################################################################
#  TODO/IDEAS:   
#          - possibility to restore time frames (incl. deleted files)
#            realizable by listing each backup and restore from 
#            oldest to the newest, problem: not performant
#          - search file in all backups function and show available
#            versions with backups date (currently impossible as only
#            current files get listed)
#          - export profile to .tgz function !!!
#          - edit profile opens conf file in vi 
#          - implement log-fd interpretation
#          - add a duplicity option check against the options pending 
#            depreciation since 0.5.10 namely --time-separator
#                                             --short-filenames
#                                             --old-filenames
#          - add support for --no-encryption switch (no GPG_KEY,GPG_PASS)
#          - add 'exclude_<command>' list usage eg. exclude_verify
#          - add 'pre/post_<command>' script support
#          - check success of pre/post scripts and react
#          - a download/install duplicity option
#
#
#  CHANGELOG:
#
#  1.5.1.1
#  - bugfix: fixed s3[+http] TARGET_PASS not needed routine
#  - bugfix: TYPO in duply 1.5.1 prohibited the use of /etc/duply
#    see https://sourceforge.net/tracker/index.php?func=detail&aid=2864410&group_id=217745&atid=1041147
#
#  1.5.1 (21.09.2009) - duply (fka. ftplicity)
#  - first things first: ftplicity (being able to support all backends since some 
#    time) will be called duply (fka. ftplicity) from now on. The addendum is for 
#    the time being to circumvent confusion.
#  - bugfix: should one duplicity command fail exit code is 1 (error) not 0 (success)
#  - s3[+http] now supported natively by translating user/password to access_key/
#    secret_key environment variables needed by duplicity s3 boto backend 
#  - bugfix: additional output lines do not confuse version check anymore
#  - list command supports now age parameter (patch by stefan on feature request tracker)
#  - bugfix: option/param pairs are now correctly passed on to duplicity
#  - bugfix: added s3[+http] to TARGET_PASS not needed if not incr/full exceptions
#
#  1.5.0.2 (31.07.1009)
#  - bugfix: insert password in target url didn't work with debian mawk
#            related to previous bug report
#
#  1.5.0.1 (23.07.2009)
#  - bugfix: gawk gensub dependency raised an error on debian's default mawk
#            replaced with match/substr command combination (bug report)
#            https://sf.net/tracker/?func=detail&atid=1041147&aid=2825388&group_id=217745
#
#  1.5.0 (01.07.2009)
#  - removed ftp limitation, all duplicity backends should work now
#  - bugfix: date for separator failed on openwrt busybox date, added a 
#    detecting workaround, milliseconds are not available w/ busybox date
#
#  1.4.2.1 (14.05.2009)
#  - bugfix: free temp space detection failed with lvm, fixed awk parse routine
#
#  1.4.2 (22.04.2009)
#  - gpg keys are now exported as gpgkey.[id].asc , the suffix reflects the
#    armored ascii nature, the id helps if the key is switched for some reason
#    im/export routines are updated accordingly (import is backward compatible 
#    to the old profile/gpgkey files)         
#  - profile argument is treated as path if it contains slashes 
#    (for details see usage)
#  - non-ftplicity options (all but --preview currently) are now passed 
#    on to duplicity 
#  - removed need for stat in secure_conf, it is ls based now
#  - added profile folder readable check
#  - added gpg version & home info output
#  - awk utility availability is now checked, because it was mandatory already
#  - tmp space is now checked on writability and space requirement
#    test fails on less than 25MB or configured $VOLSIZE, 
#    test warns if there is less than two times $VOLSIZE because 
#    that's required for --asynchronous-upload option  
#  - gpg functionality is tested now before executing duplicity 
#    test drive contains encryption, decryption, comparison, cleanup
#    this is meant to detect non trusted or other gpg errors early
#  - added possibility of doing symmetric encryption with duplicity
#    set GPG_KEY="" or simply comment it out
#  - added hints in config template on the depreciation of 
#    --short-filenames, --time-separator duplicity options
#
#  new versioning scheme 1.4.2b => 1.4.2, 
#  beta b's are replaced by a patch count number e.g. 1.4.2.1 will be assigned
#  to the first bug fixing version and 1.4.2.2 to the second and so on
#  also the releases will now have a release date formatted (Day.Month.Year)
#
#  1.4.1b1 - bugfix: ftplicity changed filesystem permission of a folder
#            named exactly as the profile if existing in executing dir
#          - improved plausibility checking of config and profile folder
#          - secure_conf only acts if needed and prints a warning now
#
#  1.4.1b  - introduce status (duplicity collection-status) command
#          - pre/post script output printed always now, not only on errors
#          - new config parameter GPG_OPTS to pass gpg options
#            added examples & comments to profile template conf
#          - reworked separator times, added duration display
#          - added --preview switch, to preview generated command lines
#          - disabled MAX_AGE, MAX_FULL_BACKUPS, VERBOSITY in generated
#            profiles because they have reasonable defaults now if not set
#
#  1.4.0b1 - bugfix: incr forces incremental backups on duplicity,
#            therefore backup translates to pre_bkp_post now
#          - bugfix: new command bkp, which represents duplicity's 
#            default action (incr or full if full_if_older matches
#            or no earlier backup chain is found)
#
#  new versioning scheme 1.4 => 1.4.0, added new minor revision number
#  this is meant to slow down the rapid version growing but still keep 
#  versions cleanly separated.
#  only additional features will raise the new minor revision number. 
#  all releases start as beta, each bugfix release will raise the beta 
#  count, usually new features arrive before a version 'ripes' to stable
#    
#  1.4.0b
#    1.4b  - added startup info on version, time, selected profile
#          - added time output to separation lines
#          - introduced: command purge-full implements duplicity's 
#            remove-all-but-n-full functionality (patch by unknown),
#            uses config variable $MAX_FULL_BACKUPS (default = 1)
#          - purge config var $MAX_AGE defaults to 1M (month) now 
#          - command full does not execute pre/post anymore
#            use batch command pre_full_post if needed 
#          - introduced batch mode cmd1_cmd2_etc
#            (in turn removed the bvp command)
#          - unknown/undefined command issues a warning/error now
#          - bugfix: version check works with 0.4.2 and older now
#    1.3b3 - introduced pre/post commands to execute/debug scripts
#          - introduced bvp (backup, verify, purge)
#          - bugfix: removed need for awk gensub, now mawk compatible
#    1.3b2 - removed pre/post need executable bit set 
#          - profiles now under ~/.ftplicity as folders
#          - root can keep profiles in /etc/ftplicity, folder must be
#            created by hand, existing profiles must be moved there
#          - removed ftplicity in path requirement
#          - bugfix: bash < v.3 did not know '=~'
#          - bugfix: purge works again 
#    1.3   - introduces multiple profiles support
#          - modified some script errors/docs
#          - reordered gpg key check import routine
#          - added 'gpg key id not set' check
#          - added error_gpg (adds how to setup gpg key howto)
#          - bugfix: duplicity 0.4.4RC4+ parameter syntax changed
#          - duplicity_version_check routine introduced
#          - added time separator, shortnames, volsize, full_if_older 
#            duplicity options to config file (inspired by stevie 
#            from http://weareroot.de) 
#    1.1.1 - bugfix: encryption reactivated
#    1.1   - introduced config directory
#    1.0   - first release
#


# important definitions #######################################################

ME_LONG="$0"
ME="$(basename $0)"
ME_NAME="${ME%%.*}"
ME_VERSION="1.5.1.1"
ME_WEBSITE="http://duply.net"

# default config values
DEFAULT_SOURCE='/path/of/source'
DEFAULT_TARGET='scheme://user[:password]@host[:port]/[/]path'
DEFAULT_TARGET_USER='_backend_username_'
DEFAULT_TARGET_PASS='_backend_password_'
DEFAULT_GPG_KEY='_KEY_ID_'
DEFAULT_GPG_PW='_GPG_PASSWORD_'

# function definitions ##########################
function set_config { # sets config vars
  CONFHOME_COMPAT="$HOME/.ftplicity"
  CONFHOME="$HOME/.duply"
  CONFHOME_ETC_COMPAT="/etc/ftplicity"
  CONFHOME_ETC="/etc/duply"

  # confdir can be delivered as path (must contain /)
  if [ `echo $FTPLCFG | grep /` ] ; then 
    CONFDIR=$(readlink -f $FTPLCFG 2>/dev/null || \
              ( echo $FTPLCFG|grep -v '^/' 1>/dev/null 2>&1 \
               && echo $(pwd)/${FTPLCFG} ) || \
              echo ${FTPLCFG})          

  # root can put profiles under /etc/ftplicity (OLD) if path exists
  elif [ -d "${CONFHOME_ETC_COMPAT}" ] && [ `id -u` -eq 0 ]; then
    CONFDIR="${CONFHOME_ETC_COMPAT}/${FTPLCFG}"
    warning " ftplicity changed name to duply since you created your profiles.
 Please rename '${CONFHOME_ETC_COMPAT}' to '${CONFHOME_ETC}' and this warning will disappear.
 If you decide not to do so profiles will only work from '{CONFHOME_ETC_COMPAT}'."

  # root can put profiles under /etc/duply (NEW) if path exists
  elif [ -d "${CONFHOME_ETC}" ] && [ `id -u` -eq 0 ]; then
 CONFDIR="${CONFHOME_ETC}/${FTPLCFG}"

  # or in home/.ftplicity folder (OLD)
  elif [ -d "${CONFHOME_COMPAT}" ]; then
    CONFDIR="${CONFHOME_COMPAT}/${FTPLCFG}"
    warning " ftplicity changed name to duply since you created your profiles.
 Please rename '~/.ftplicity' to '~/.duply' and this warning will disappear.
 If you decide not to do so profiles will only work from '~/.ftplicity'."

  # or DEFAULT in home/.duply folder (NEW)
  else
    CONFDIR="${CONFHOME}/${FTPLCFG}"
  fi

  CONF="$CONFDIR/conf"
  PRE="$CONFDIR/pre"
  POST="$CONFDIR/post"
  EXCLUDE="$CONFDIR/exclude"
  KEYFILE="$CONFDIR/gpgkey.asc"
}

function version_info { # print version information
  cat <<END
  $ME version $ME_VERSION
  ($ME_WEBSITE)
END
}

function usage_info { # print usage information

  cat <<USAGE
VERSION:
$(version_info)
  
DESCRIPTION: 
  Duply deals as a wrapper for the mighty duplicity magic.
  It simplifies running duplicity with cron or on command line by:

   - keeping settings in profiles per backup job 
   - enabling batch actions eg. backup_verify_purge
   - executing pre/post scripts
   - precondition checking for flawless duplicity operation 

  For each backup job one configuration profile must be created.
  The profile folder will be stored under '~/.${ME_NAME}/<profile>'
  (where ~ is the current users home directory).
  Hint:
  If the folder '/etc/${ME_NAME} exists the profiles for the super 
  user root will be searched & created there.
      
USAGE:
  first time usage (profile creation)
    $ME <profile> create
  
  general usage in single or batch mode (see EXAMPLES)
    $ME <profile> <command>[_<command>_...] [<options> ...]
    
  Non $ME options are passed on to duplicity (see OPTIONS).
             
PROFILE:    
  Indicated by a profile _name_ (<profile>), which is resolved to 
  '~/.${ME_NAME}/<profile>' (~ expands to environment variable \$HOME).
  
  Superuser root can place profiles under '/etc/${ME_NAME}' if the
  folder is manually created before running $ME.
  ATTENTION: 
    If '/etc/${ME_NAME}' is created, old profiles under 
    '~root/.${ME_NAME}/<profile>' have to be moved manually 
    to the former or will cease to work.
             
  example 1:   $ME humbug backup
    
  Alternatively a _path_ might be used. This might be useful for quick testing, 
  restoring or exotic locations. Shell expansion should work as usual.
  ATTENTION: 
    The path must contain at least one '/', e.g './test' instead of only 'test'.
             
  example 2:   $ME ~/.${ME_NAME}/humbug backup
             
COMMANDS:
  usage:     get usage help text
  create:    creates a configuration profile
  backup:    backup with pre/post script execution (batch: pre_bkp_post),
              full - if parameter full_if_older matches 
                     or no earlier backup is found
              incremental - in all other cases
  bkp:       as above but without executing pre/post scripts
  full:      force full backup
  incr:      force incremental backup
  list [<age>]:      
             list all files in backup (as it was at <age>, default: now)
  status:    prints backup sets and chains currently in repository
  verify:    list files changed since latest backup
  purge [--force]:
             shows outdated backup archives (older than \$MAX_AGE)
             [--force, delete these files]
  purge-full [--force]:
             shows outdated backups (more than \$MAX_FULL_BACKUPS, 
             the number of 'recent' full backups and associated 
             incrementals to keep)
             [--force, delete these files]             
  cleanup [--force]:
             shows broken backup archives (e.g. after unfinished run)
             [--force, delete these files]
  restore <target_path> [<age>]:
             restore the backup to <target_path> 
             [as it was at <age>]             
  fetch <src_path> <target_path> [<age>]:
             restore single file/folder from backup 
             [as it was at <age>]
  pre/post:  execute <profile>/$(basename "$PRE") or <profile>/$(basename "$POST") script
             (for debugging purposes)  

OPTIONS:
  --force:   passed to duplicity (see commands: purge, purge-full, cleanup)
  --preview: do nothing but print out generated duplicity command lines

EXAMPLES:
  create profile 'humbug':
    $ME humbug create (now edit the resulting conf file)
  backup 'humbug' now:
    $ME humbug backup
  list available backup sets of profile 'humbug':  
    $ME humbug status
  list and delete obsolete backup archives of 'humbug':
    $ME humbug purge --force
  restore latest backup of 'humbug' to /mnt/restore:
    $ME humbug restore /mnt/restore
  restore /etc/passwd of 'humbug' from 4 days ago to /root/pw:
    $ME humbug fetch etc/passwd /root/pw 4D
    (see "man duplicity", section TIME FORMATS)
  a one line batch job on 'humbug' for cron execution
    $ME humbug backup_verify_purge --force

FILES in the profile folder(~/.${ME_NAME}/<profile>):
  conf             main configuration file
  pre              executed _before_ a backup
  post             executed _after_ a backup
  gpgkey.*.asc     exported GPG key file(s)
  exclude          a globbing list of included or excluded files/folders
                   (see "man duplicity", section FILE SELECTION)

$(hint_profile)

USAGE
}

function create_config {
  if [ ! -d "$CONFDIR" ] ; then
    mkdir -p "$CONFDIR" || error "Couldn't create config '$CONFDIR'."
  # create initial config file
    cat <<EOF >"$CONF"
# gpg key data (for symmetric encryption comment out GPG_KEY)
GPG_KEY='${DEFAULT_GPG_KEY}'
GPG_PW='${DEFAULT_GPG_PW}'
# gpg options passed from duplicity to gpg process (default='')
# e.g. "--trust-model pgp|classic|direct|always" 
#   or "--compress-algo=bzip2 --bzip2-compress-level=9"
#GPG_OPTS=''

# credentials & server address of the backup target (URL-Format)
# syntax is
#   scheme://[user:password@]host[:port]/[/]path
# probably one out of
#   file:///some_dir
#   ftp://user[:password]@other.host[:port]/some_dir
#   hsi://user[:password]@other.host/some_dir
#   cf+http://container_name
#   imap://user[:password]@host.com[/from_address_prefix]
#   imaps://user[:password]@host.com[/from_address_prefix]
#   rsync://user[:password]@other.host[:port]::/module/some_dir
#   rsync://user[:password]@other.host[:port]/relative_path
#   rsync://user[:password]@other.host[:port]//absolute_path
#   # for the s3 user/password are AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
#   s3://[user:password]@host/bucket_name[/prefix]
#   s3+http://[user:password]@bucket_name[/prefix]
#   scp://user[:password]@other.host[:port]/some_dir
#   ssh://user[:password]@other.host[:port]/some_dir
#   tahoe://alias/directory
#   webdav://user[:password]@other.host/some_dir
#   webdavs://user[:password]@other.host/some_dir 
###
TARGET='${DEFAULT_TARGET}'
# optionally the username/password can be defined as extra variables
# setting them here _and_ in TARGET results in an error
#TARGET_USER='${DEFAULT_TARGET_USER}'
#TARGET_PASS='${DEFAULT_TARGET_PASS}'

# base directory to backup
SOURCE='${DEFAULT_SOURCE}'

# Time frame for old backups to keep, Used for the "purge" command.  
# see duplicity man page, chapter TIME_FORMATS)
# defaults to 1M, if not set
#MAX_AGE=1M

# Number of full backups to keep. Used for the "purge-full" command. 
# See duplicity man page, action "remove-all-but-n-full".
# defaults to 1, if not set 
#MAX_FULL_BACKUPS=1

# verbosity of output (5 for gpg errors, 9 for bug fixing)
# default is 4, if not set
#VERBOSITY=5

# temporary file space. at least the size of the biggest file in backup
# for a successful restoration process. (default is '/tmp', if not set)
#TEMP_DIR=/tmp

# sets duplicity --time-separator option (since v0.4.4.RC2) to allow users 
# to change the time separator from ':' to another character that will work 
# on their system.  HINT: For Windows SMB shares, use --time-separator='_'.
# NOTE: '-' is not valid as it conflicts with date separator.
# ATTENTION: only use this with duplicity < 0.5.10, since then default file 
#            naming is compatible and this option is pending depreciation 
#DUPL_PARAMS="\$DUPL_PARAMS --time-separator _ "

# activates duplicity --short-filenames option, when uploading to a file
# system that can't have filenames longer than 30 characters (e.g. Mac OS 8)
# or have problems with ':' as part of the filename (e.g. Microsoft Windows)
# ATTENTION: only use this with duplicity < 0.5.10, later versions default file 
#            naming is compatible and this option is pending depreciation
#DUPL_PARAMS="\$DUPL_PARAMS --short-filenames "
 
# activates duplicity --full-if-older-than option (since duplicity v0.4.4.RC3) 
# forces a full backup if last full backup reaches a specified age, for the 
# format of MAX_FULLBKP_AGE see duplicity man page, chapter TIME_FORMATS
#MAX_FULLBKP_AGE=1M
#DUPL_PARAMS="\$DUPL_PARAMS --full-if-older-than \$MAX_FULLBKP_AGE " 

# sets duplicity --volsize option (available since v0.4.3.RC7)
# set the size of backup chunks to VOLSIZE MB instead of the default 25MB.
# VOLSIZE must be number of MB's to set the volume size to. 
#VOLSIZE=50
#DUPL_PARAMS="\$DUPL_PARAMS --volsize \$VOLSIZE "

# more duplicity command line options can be added in the following way
# don't forget to leave a separating space char at the end
#DUPL_PARAMS="\$DUPL_PARAMS --put_your_options_here " 

EOF

  # secure newly created conf
  secureconf

  # Hints on first usage
  cat <<EOF

Congratulations. You just created the profile '$FTPLCFG'.
The initial config file has been created as 
'$CONF'.
You should now adjust this config file to your needs.

$(hint_profile)

EOF
fi

}

# used in usage AND create_config
function hint_profile {
  cat <<EOF
IMPORTANT:
  Copy the _whole_ profile folder after the first backup to a safe place.
  It contains everything needed to restore your backups. You will need 
  it if you have to restore the backup from another system (e.g. after a 
  system crash). Keep access to these files restricted as they contain 
  _all_ informations (gpg data, ftp data) to access and modify your backups.

  Repeat this step after _all_ configuration changes. Some configuration 
  options are crucial for restoration.

EOF
}

function separator {
  echo "--- $@ ---"
}

function inform {
  echo -e "\nINFO:\n\n$@\n"
}

function warning {
  echo -e "\nWARNING:\n\n$@\n"
}

function error {
  echo -e "\nSorry. A fatal ERROR occured:\n\n$@\n"
  exit -1
}

function error_gpg {
  error "$@

Hint:

  Maybe you have not created a gpg key yet (e.g. gpg --gen-key)?
  Don't forget the used _password_ as you will need it.
  When done enter the 8 digit id & the password in the profile conf file.

  The key id can be found doing a 'gpg --list-keys'. In the 
  example output below the key id would be FFFFFFFF.

  pub   1024D/FFFFFFFF 2007-12-17
  uid                  duplicity
  sub   2048g/899FE27F 2007-12-17
"
}

function duplicity_version_check {
   DUPL_VERSION=`$DUPLICITY --version 2>&1 | awk '/^duplicity /{printf $2; exit;}'`
   #DUPL_VERSION='bla0.4.b4.RC4'
   DUPL_VERSION_VALUE=`echo $DUPL_VERSION | awk -F. '{if($1$2$3~/^[0-9]+$/)$0=$1*10000+$2*100+$3;else $0=0; print}'`
   DUPL_VERSION_RC=`echo $DUPL_VERSION | awk '{pos=match($0,/RC([0-9]+)$/);if(pos)print substr($0,pos+2);else print 0}'`
   #echo "dv = $DUPL_VERSION $DUPL_VERSION_VALUE $DUPL_VERSION_RC"

   if [ $DUPL_VERSION_VALUE -eq 0 ]; then
      echo -e "duplicity ($DUPL_VERSION) (please report, this is a bug)" 
   elif [ $DUPL_VERSION_VALUE -le 404 -a $DUPL_VERSION_RC -lt 4 ]; then
      error "The installed version $DUPL_VERSION is incompatible with $ME v$ME_VERSION.
You should upgrade your version of duplicity to at least v0.4.4RC4 or
use the older $ME version 1.1.1 from $ME_WEBSITE."
   else
      echo -e "duplicity version $DUPL_VERSION"
   fi

}

function run_script { # run pre/post scripts
  SCRIPT="$1"
  CMD=". ${SCRIPT} 2>&1"
  if [ -r "$SCRIPT" -a ! -z "$PREVIEW" ] ; then	
    echo "Skipped executing '$CMD' in preview mode" 	
  elif [ -r "$SCRIPT" ] ; then 
  	echo -n "Running '$SCRIPT' "
  	OUT=`. "$SCRIPT" 2>&1`; ERR=$?
  	[ $ERR -eq "0" ] && echo "- OK" || echo "- FAILED (code $ERR)"
  	echo -en ${OUT:+"Output: $OUT\n"} ;
  else
    echo "Skipping n/a script '$SCRIPT'."
  fi
}

function run_ftply { # run ftply error checked
  echo -n "Running duplicity "
  OUT=$(ftply $@ 2>&1); ERR="${?-none}"
  [ $ERR -eq 0 ] && echo "- OK" || echo "- FAILED (code $ERR)"
  echo -en ${OUT:+"Output: $OUT\n"}
  
  [ $ERR -ne 0 ] && FTPL_ERR=1
}

function ftply { # the actual wrapper function

  # put command (with params) first in duplicity parameters
  for param in "$@" ; do
    # split cmd from params (everything before splittchar --)
    if [ "$param" == "--" ] ; then
      PARAMSONLY=1
    else 
      [ ! $PARAMSONLY ] && \
        DUPL_CMD="$DUPL_CMD $param" \
      || \
        DUPL_PARAMS="$DUPL_PARAMS $param"
    fi
  done

  # use key only if set in config, else leave it to symmetric encryption
  GPG_KEY=${GPG_KEY:+"--encrypt-key $GPG_KEY --sign-key $GPG_KEY"}

  # print or exec duplicity
  [ -n "$PREVIEW" ] && ECHO='echo'

  eval $ECHO PASSPHRASE="$GPG_PW" \
  TMPDIR="$TEMP_DIR" ${BACKEND_PARAMS} \
  $DUPLICITY $DUPL_CMD --verbosity "${VERBOSITY:-4}" $GPG_KEY \
  --gpg-options=\"$GPG_OPTS\" $DUPL_PARAMS

  return $?
}

function secureconf { # secure the configuration dir
  PERMS=$(ls -la $(dirname $CONFDIR) | grep -e " $(basename $CONFDIR)\$" | awk '{print $1}')
  if [ "$PERMS" != 'drwx------' ] ; then
  	warning "The profile's folder 
'$CONFDIR'
permissions were not safe ($PERMS). Secured them to 700."
  	chmod -R 700 "$CONFDIR" || error "Could not chmod access on '$CONFDIR'."
  fi
}

function date_fix {
  if [ ! -z "$(date -h 2>&1 | grep BusyBox)" ] ; then
    echo $(date -d $1 -D %s +"%T")
  else
    echo $(date --date=@$1 +%T)
  fi
}

function var_isset {
  if [ -z "$1" ]; then
    echo "ERROR: function var_isset needs a string as parameter"
  elif eval "[ \"\${$1}\" == 'not_set' ]" || eval "[ \"\${$1-not_set}\" != 'not_set' ]"; then
    return 0
  fi
  return 1
}

# start of script #######################################################################

# confidentiality first, all we create is only readable by us
umask 077

# check if ftplicity is there & executable
[ -n "$ME_LONG" -a -x "$ME_LONG" ] || error "$ME missing. Executable & available in path? ($ME_LONG)"

# deal with the profile
if [ -z "$FTPLCFG" ]; then

	if [ ${#@} -gt 1 ]; then
		FTPLCFG="${1}"; cmd="${2}";
	else
		cmd="${1}"
	fi
  
	# what to do
	# show requested version
    # OR requested usage info
	# OR create a profile
	# OR run on selected profile
	# OR show usage help
	case "$cmd" in
      version|--version|-v|-V)
        version_info
        exit 0
        ;;
      usage|--help|-h|-H)
        usage_info
        exit 0
        ;;	
	  create)
	    set_config
	    if [ -d $CONFDIR ]; then
			error "The profile '$FTPLCFG' already exists in
'$CONFDIR'.

Hint:
 If you _really_ want to create a new profile by this name you will 
 have to manually delete the existing profile folder first."
 			exit 1
	    else
			create_config
			exit 0
	    fi
	    ;;
	
	  *)
	    if [ -z "$FTPLCFG" ] || set_config > /dev/null && [ ! -d "$CONFDIR" ]; then 
	      error "Selected profile '$FTPLCFG' does not resolve to a profile folder in
'$CONFDIR'.

Hints: 
 Use '$ME <name> create' to create a profile first.
 Use '$ME usage' to get usage help."
	    elif [ ! -x "$CONFDIR" ]; then
	      error "Profile folder in '$CONFDIR' cannot be accessed.
	      
Hint: 
 Check the filesystem permissions and set directory accessible e.g. 'chmod 700'."
	    else
	      export FTPLCFG=$FTPLCFG
	      shift
	      $ME_LONG $*
	      exit $?
	    fi    
	    ;;    
	esac

fi

# Hello world
echo "Start $ME v$ME_VERSION, time is $(date +'%D %T')."

# set profile path
set_config
echo "Using profile '$CONFDIR'."

# check system environment
DUPLICITY="$(which duplicity)"
[ -z "$DUPLICITY" ] && error "duplicity missing. installed und available in path?"

GPG="$(which gpg)"
[ -z "$GPG" ] && error "gpg missing. installed und available in path?"

[ -z "$(which awk)" ] && error "awk missing. installed und available in path?"

# exec & output duplicity version check info
echo -en "Using installed $(duplicity_version_check), "

# output gpg version info
echo -e `$GPG --version | awk '/^gpg/{v=$1" "$3};/^Home/{print v" ("$0")"}'`

# read configuration
if [ ! -f "$CONF" ] ; then
  error "'$CONF' not found."
elif [ ! -r "$CONF" ] ; then
  error "'$CONF' not readable."
else
  . "$CONF"
  KEYFILE="${KEYFILE//.asc/${GPG_KEY:+.$GPG_KEY}.asc}"
  # backward compatibility: old TARGET_PW overrides silently new TARGET_PASS if set
  if var_isset 'TARGET_PW'; then
    TARGET_PASS="${TARGET_PW}"
  fi
fi

# split TARGET in handy variables, remove invalid chars ('") to protect script
TARGET_SPLIT_URL=$(awk -v target="$TARGET" 'BEGIN { \
  gsub(/[\047\042]/,"",target); match(target,/^([^\/:]+):\/\//); \
  prot=substr(target,RSTART,RLENGTH);rest=substr(target,RSTART+RLENGTH); \
  if (credsavail=match(rest,/^[^@]*@/)){\
    creds=substr(rest,RSTART,RLENGTH-1);\
    credcount=split(creds,cred,":");\
    rest=substr(rest,RLENGTH+1);\
  }print "TARGET_URL_PROT=\047"prot"\047\n"\
         "TARGET_URL_HOSTPATH=\047"rest"\047\n"\
         "TARGET_URL_CREDS=\047"creds"\047\n";\
   if(credsavail){print "TARGET_URL_USER=\047"cred[1]"\047\n"}\
   if(credcount>1){print "TARGET_URL_PASS=\047"cred[2]"\047\n"}\
  }')
eval ${TARGET_SPLIT_URL}

# fetch commmand from parameters ########################################################
# Hint: cmds is also used to check if authentification info sufficient in the next step 
cmds="$1"; shift;

# translate backup to batch command 
cmds=${cmds//backup/pre_bkp_post}

# complain if command(s) missing
[ -z $cmds ] && error "  No command given.

  Hint: 
    Use '$ME usage' to get usage help."

# plausibility check config - VARS & KEY ################################################
# check if src, trg, trg pw
# auth info sufficient 
# gpg key, gpg pwd (might be empty) set in config
# OR key in local gpg db
# OR key can be imported from keyfile 
# OR fail
if [ -z "$SOURCE" -o "$SOURCE" == "${DEFAULT_SOURCE}" ]; then
 error " Source Path (setting SOURCE) not set or still default value in conf file 
 '$CONF'."

elif [ -z "$TARGET" -o "$TARGET" == "${DEFAULT_TARGET}" ]; then
 error " Backup Target (setting TARGET) not set or still default value in conf file 
 '$CONF'."

elif var_isset 'TARGET_USER' && var_isset 'TARGET_URL_USER' && \
     [ "${TARGET_USER}" != "${TARGET_URL_USER}" ]; then
 error " TARGET_USER ('${TARGET_USER}') _and_ user in TARGET url ('${TARGET_URL_USER}') 
 are configured with different values. There can be only one.
 
 Hint: Remove conflicting setting."

elif var_isset 'TARGET_PASS' && var_isset 'TARGET_URL_PASS' && \
     [ "${TARGET_PASS}" != "${TARGET_URL_PASS}" ]; then
 error " TARGET_PASS ('${TARGET_PASS}') _and_ password in TARGET url ('${TARGET_URL_PASS}') 
 are configured with different values. There can be only one.
 
 Hint: Remove conflicting setting."
fi

# check if authentication information sufficient
if ( ( ! var_isset 'TARGET_USER' && ! var_isset 'TARGET_URL_USER' ) || \
       ( ! var_isset 'TARGET_PASS' && ! var_isset 'TARGET_URL_PASS' ) ); then
  # ok here some exceptions:
  #   file/tahoe do not need passwords
  #   s3[+http] only needs password for write operations
  [ -n "$(echo ${TARGET_URL_PROT} | grep -e '^s3\(\+http\)\?://$')" ] && echo jess
  echo "${cmds}|$(echo ${cmds} | grep -e '\(backup\|incr\|full\)')"
  if [ -n "$(echo ${TARGET_URL_PROT} | grep -e '^\(file\|tahoe\)://$')" ]; then
    : # all is well file/tahoe do not need passwords
  elif [ -n "$(echo ${TARGET_URL_PROT} | grep -e '^s3\(\+http\)\?://$')" ] && \
     [ -z "$(echo ${cmds} | grep -e '\(bkp\|incr\|full\|purge\|cleanup\)')" ]; then
    : # still fine, it's possible to read only access configured buckets anonymously
  else
    error " Backup target credentials needed but not set in conf file 
 '$CONF'.
 Setting TARGET_USER or TARGET_PASS or the corresponding values in TARGET url 
 are missing. Some protocols only might need it for write access to the backup 
 repository (commands: bkp,backup,full,incr,purge) but not for read only access
 (e.g. verify,list,restore,fetch). 
 
 Hints:
   Add the credentials (user,password) to the conf file.
   To force an empty password set TARGET_PASS='' or TARGET='pro://user:@host..'.
"
  fi
fi

# check gpg key data plausibility
if [ "$GPG_KEY" == "${DEFAULT_GPG_KEY}" ] || [ ! -z "$GPG_KEY" ] && [ ! $(echo $GPG_KEY | grep '^[0-9a-fA-F]\{8\}$') ]; then
	error_gpg "Encryption Key GPG_KEY not set correct (8 digit ID) 
or still default in conf file '$CONF'."

elif [ "${GPG_PW-not_set}" == 'not_set' -o "$GPG_KEY" == "${DEFAULT_GPG_KEY}" ]; then
    error_gpg "Encryption Password GPG_PW not set or still default value in conf file 
'$CONF'."
    
elif [ ! -z "$GPG_KEY" -a  $($GPG --list-secret-key $GPG_KEY >/dev/null 2>&1;echo $?) -ne 0 ] ; then
    echo "Encryption Key '$GPG_KEY' not found."

    # Try autoimport from existing old gpgkey files and new gpgkey.XXX.asc files (since v1.4.2)
    for file in `ls $CONFDIR/gpgkey $KEYFILE 2>/dev/null`; do

        echo -n -e "\nTry to import from existing keyfile \n'$file'. -> "
        OUT=`$GPG --batch --import "$file" 2>&1`; ERR=$? 
        [ "$ERR" -eq 0 ] && echo "SUCCESS" || echo "FAILED"
        
        if [ "$ERR" -ne 0 ]; then
            echo -e "gpg output:\n$OUT"
        else
            echo -e "\nFor $ME to work you have to set the trust level 
with the command \"trust\" to \"ultimate\" (5) now.
Exit the edit mode of gpg with \"quit\".\n"
                sleep 5
                $GPG --edit-key $GPG_KEY
        fi        

    done

    # still no key? failure
    if [ $($GPG --list-secret-key $GPG_KEY >/dev/null 2>&1;echo $?) -ne 0 ] ; then
    	error_gpg "Key $GPG_KEY cannot be found.$?
Doublecheck if the above key is listed by gpg (gpg --list-keys)
or available as gpg key file '$(basename $KEYFILE)' or  'gpgkey' 
in the profile folder."
    fi
    
fi


# config plausibility check - SPACE #####################################################
# init tmp default value
# is tmp writeable
# is tmp big enough
TEMP_DIR=${TEMP_DIR:-'/tmp'}
if [ ! -d "$TEMP_DIR" ]; then
    error "Temporary file space '$TEMP_DIR' is not a directory."
elif [ ! -w "$TEMP_DIR" ]; then
    error "Temporary file space '$TEMP_DIR' not writable."
fi

# get volsize, default duplicity volume size is 25MB since v0.5.07
VOLSIZE=${VOLSIZE:-25}
# get free temp space
TEMP_FREE="$(df $TEMP_DIR 2>/dev/null | awk 'END{pos=(NF-2);if(pos>0) print $pos;}')"
# check for free space or FAIL
if [ "$((${TEMP_FREE:-0}-${VOLSIZE:-0}*1024))" -lt 0 ]; then
    error "Temporary file space '$TEMP_DIR' free space is smaller ($((TEMP_FREE/1024))MB)
than one duplicity volume (${VOLSIZE}MB).
    
  Hint: Free space or change TEMP_DIR setting."
fi

# check for enough async upload space and WARN only
if [ $((${TEMP_FREE:-0}-2*${VOLSIZE:-0}*1024)) -lt 0 ]; then
    warning "Temporary file space '$TEMP_DIR' free space is smaller ($((TEMP_FREE/1024))MB)
than two duplicity volumes (2x${VOLSIZE}MB). This can lead to problems when 
using the --asynchronous-upload option.
    
  Hint: Free space or change TEMP_DIR setting."
fi

# test - GPG SANITY #####################################################################
function cleanup_gpgtest { 
  echo -en "Cleanup - Delete '${GPG_TEST}_*'"
  rm ${GPG_TEST}_* 2>/dev/null && echo "(OK)" || echo "(FAILED)"
}
GPG_TEST="$TEMP_DIR/${ME_NAME}.$$.$(date +%s)"
# using keys
if [ ! -z "$GPG_KEY" ]; then
	# check encrypting
	echo -en "Test - Encryption with key $GPG_KEY "
	OUT=`$GPG -r $GPG_KEY -o ${GPG_TEST}_ENC --batch $GPG_OPTS -e $ME_LONG 2>&1`; ERR=$?
	
	if [ $ERR == 0 ]; then 
	    echo "(OK)"
	else
	    echo "(FAILED)"; cleanup_gpgtest; error "$OUT
	
  Hint: On 'no assurance' error try to 'gpg --edit-key $GPG_KEY' 
        and raise the trust level to ultimate. 
        Alternatively set GPG_OPTS='--always-trust' in conf file."
	fi
	
	# check decrypting
	echo -en "Test - Decryption with key $GPG_KEY "
	OUT=`echo "$GPG_PW" | $GPG --passphrase-fd 0 -r $GPG_KEY -o ${GPG_TEST}_DEC --batch $GPG_OPTS -d ${GPG_TEST}_ENC 2>&1`; ERR=$?
	if [ $ERR == 0 ]; then 
	    echo "(OK)"
	else
	    echo "(FAILED)"; cleanup_gpgtest; error "$OUT"
	fi
# symmetric only
else
	# check encrypting
	echo -en "Test - Encryption with passphrase "
	OUT=`echo "$GPG_PW" | $GPG --passphrase-fd 0 -o ${GPG_TEST}_ENC --batch $GPG_OPTS -c $ME_LONG 2>&1`; ERR=$?
	
	if [ $ERR == 0 ]; then 
	    echo "(OK)"
	else
	    echo "(FAILED)"; cleanup_gpgtest; error "$OUT"
	fi
	
	# check decrypting
	echo -en "Test - Decryption with passphrase "
	OUT=`echo "$GPG_PW" | $GPG --passphrase-fd 0 -o ${GPG_TEST}_DEC --batch $GPG_OPTS -d ${GPG_TEST}_ENC 2>&1`; ERR=$?
	if [ $ERR == 0 ]; then 
	    echo "(OK)"
	else
	    echo "(FAILED)"; cleanup_gpgtest; error "$OUT"
	fi	
fi

# compare original w/ decryptginal
echo -n "Test - Compare Original w/ Decryption "
if [ "$(cat $ME_LONG)" == "$(cat ${GPG_TEST}_DEC)" ]; then 
    echo "(OK)"; cleanup_gpgtest
else
    echo "(FAILED)"; error "This is a major failure. 
Please report to the author and attach files '${GPG_TEST}_*' and '$ME_LONG'"
fi


# Exclude file is needed, create it if necessary
[ -f "$EXCLUDE" ] || touch "$EXCLUDE"

# secure config dir, if needed w/ warning
secureconf

# export key if not already #############################################################
# TODO: export again if key changed, how to detect?
if [ ! -z "$GPG_KEY" -a ! -f "$KEYFILE" ] ; then
     touch "$KEYFILE" && chmod 0600 "$KEYFILE"
     $GPG --armor --export $GPG_KEY >>"$KEYFILE"
     $GPG --armor --export-secret-keys $GPG_KEY >>"$KEYFILE"
     inform "Backup of used key ($GPG_KEY) did not exist as file
'$KEYFILE' .
Created it now.

Hint: You should backup your changed profile folder now."    
fi


# command execution #####################################################################

# process params
for param in "$@" ; do
  case "$param" in
    # enable ftplicity preview mode
    '--preview')
      PREVIEW=1
      ;;
    *)
      if [ `echo "$param" | grep -e "^-"` ] || \
         [ `echo "$last_param" | grep -e "^-"` ] ; then
        # forward parameter[/option pairs] to duplicity
        dupl_opts["${#dupl_opts[@]}"]=${param}
      else
        # anything else must be a parameter (eg. for fetch, ...)
        ftpl_pars["${#ftpl_pars[@]}"]=${param}
      fi
      last_param=${param}
      ;;
  esac
done

# possibly set TARGET_USER&PASS vars replace their URL pendants (double defs already dealt with)
var_isset 'TARGET_USER' && TARGET_URL_USER="${TARGET_USER}"
var_isset 'TARGET_PASS' && TARGET_URL_PASS="${TARGET_PASS}"

# build target url depending on protocol
case "${TARGET_URL_PROT}" in
  # enable ftplicity preview mode
  's3://'|'s3+http://')
    BACKEND_PARAMS="AWS_ACCESS_KEY_ID='${TARGET_URL_USER}' AWS_SECRET_ACCESS_KEY='${TARGET_URL_PASS}'"
    BACKEND_URL="${TARGET_URL_PROT}${TARGET_URL_HOSTPATH}"
    ;;
  'file://'|'tahoe://')
    BACKEND_URL="${TARGET_URL_PROT}${TARGET_URL_HOSTPATH}"
    ;;
  *)
    ( var_isset 'TARGET_URL_USER' || var_isset 'TARGET_URL_PASS' ) && \
      BACKEND_CREDS="${TARGET_URL_USER}:${TARGET_URL_PASS}@"
    BACKEND_URL="${TARGET_URL_PROT}${BACKEND_CREDS}${TARGET_URL_HOSTPATH}"
    ;;
esac
# protect eval from special chars in url (e.g. open ')' in password)
BACKEND_URL="'$BACKEND_URL'"

# run cmds of the converted space separated commandlist  
for cmd in ${cmds//_/ };
do

# busybox date workaround
NSECS=$(date +%N | grep -v %); NSECS=${NSECS:-000000000}
RUN_START=$(date +%s$NSECS)
echo; separator "Start running command $(echo $cmd|awk '$0=toupper($0)') $(date_fix  $(($RUN_START/1000000000))).$(printf "%03d" $((RUN_START/1000000%1000)) )"

case "$cmd" in
  pre|post)
    [ "$cmd" == 'pre' ] && script=$PRE || script=$POST
    run_script $script
    ;;
  bkp)
    run_ftply -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$SOURCE" "$BACKEND_URL"
    ;;
  incr)
    run_ftply incr -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$SOURCE" "$BACKEND_URL"
    ;;
  full)
    run_ftply full -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$SOURCE" "$BACKEND_URL"
    ;;
  verify)
    run_ftply verify -- "${dupl_opts[@]}" --exclude-globbing-filelist "$EXCLUDE" \
          "$BACKEND_URL" "$SOURCE"
    ;;
  list)
    # time param exists since 0.5.10+
    TIME="${ftpl_pars[0]:-now}"
    run_ftply list-current-files -- -t "$TIME" "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  cleanup)
    run_ftply cleanup -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  purge)
    run_ftply remove-older-than "${MAX_AGE:-1M}" \
          -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  purge-full)
    run_ftply remove-all-but-n-full "${MAX_FULL_BACKUPS:-1}" \
          -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;
  restore)
    OUT_PATH="${ftpl_pars[0]}"; TIME="${ftpl_pars[1]:-now}";
    [ -z "$OUT_PATH" ] && error "  Missing parameter target_path for restore.
  
  Hint: 
    Syntax is -> $ME restore <target_path> [<age>]"
    
    run_ftply  -- -t "$TIME" "${dupl_opts[@]}" "$BACKEND_URL" "$OUT_PATH"
    ;;
  fetch)
    IN_PATH="${ftpl_pars[0]}"; OUT_PATH="${ftpl_pars[1]}"; 
    TIME="${ftpl_pars[2]:-now}";
    [ -z "$IN_PATH" -o -z "$OUT_PATH" ] && error "  Missing parameter src_path or target_path for fetch.
  
  Hint: 
    Syntax is -> $ME fetch <src_path> <target_path> [<age>]"
    
    # duplicity 0.4.7 doesnt like cmd restore in combination with --file-to-restore
    run_ftply -- --restore-time "$TIME" "${dupl_opts[@]}" \
              --file-to-restore "$IN_PATH" "$BACKEND_URL" "$OUT_PATH"
    ;;
  status)
    run_ftply collection-status -- "${dupl_opts[@]}" "$BACKEND_URL"
    ;;    
  *)
    warning "Unknown command '$cmd'."
    ;;
esac


NSECS=$(date +%N | grep -v %); NSECS=${NSECS:-000000000}
RUN_END=$(date +%s)$NSECS ; RUNTIME=$(( $RUN_END - $RUN_START ))
separator "Finished $(date_fix $(($RUN_END/1000000000))).$(printf "%03d" $((RUN_END/1000000%1000)) ) - \
Runtime $(printf "%02d:%02d:%02d.%03d" $((RUNTIME/1000000000/60/60)) $((RUNTIME/1000000000/60%60)) $((RUNTIME/1000000000%60)) $((RUNTIME/1000000%1000)) )"

done

exit ${FTPL_ERR}
