#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# This script is intended to be ran on RHEL 7 and distros that were based off it.  Other distros of Linux have different sets of STIGs.

#--------------------------------------------
#STIGs for Red Hat 7, Version 3 Release 13.
#--------------------------------------------

#--------------
#CAT III\Low
#--------------

#Set yum to remove unneeded packages, V-204452
function V204452() {
    local Regex1="^(\s*)#clean_requirements_on_remove=\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#clean_requirements_on_remove=\S+(\s*#.*)?\s*$/clean_requirements_on_remove=1\2/"
    local Regex3="^(\s*)clean_requirements_on_remove=\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)clean_requirements_on_remove=\S+(\s*#.*)?\s*$/clean_requirements_on_remove=1\2/"
    local Regex5="^(\s*)clean_requirements_on_remove=1?\s*$"
    local Success="Yum set to remove unneeded packages, per V-204452."
    local Failure="Failed to set yum to remove unneeded packages, not in compliance V-204452."

    echo
    ( (grep -E -q "${Regex1}" /etc/yum.conf && sed -ri "${Regex2}" /etc/yum.conf) || (grep -E -q "${Regex3}" /etc/yum.conf && sed -ri "${Regex4}" /etc/yum.conf)) || echo "clean_requirements_on_remove=1" >>/etc/yum.conf
    (grep -E -q "${Regex5}" /etc/yum.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set mx concurrent sessions to 10, V-204576
function V204576() {
    local Regex1="^(\s*)#*\s*hard\s*maxlogins\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#*\s*hard\s*maxlogins\s+\S+(\s*#.*)?\s*$/\* hard maxlogins 10\2/"
    local Regex3="^(\s*)\*\s*hard\s*maxlogins\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)\*\s*hard\s*maxlogins\s+\S+(\s*#.*)?\s*$/\* hard maxlogins 10\2/"
    local Regex5="^(\s*)\*\s*hard\s*maxlogins\s*10?\s*$"
    local Success="Set max concurrent sessions to 10, per V-204576."
    local Failure="Failed to set max concurrent sessions to 10, not in compliance V-204576."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/limits.conf && sed -ri "${Regex2}" /etc/security/limits.conf) || (grep -E -q "${Regex3}" /etc/security/limits.conf && sed -ri "${Regex4}" /etc/security/limits.conf)) || echo "* hard maxlogins 10" >>/etc/security/limits.conf
    (grep -E -q "${Regex5}" /etc/security/limits.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

##Apply all compatible CATIII
function Low() {
    echo
    echo "----------------------------------"
    echo " Applying all compatible CAT IIIs"
    echo "----------------------------------"

    #Check if pam is installed for V204576, V204605
    if yum -q list installed pam &>/dev/null; then
        V204576
    else
        echo
        echo "Pam is not installed skipping V-204576 and V-204605."
    fi

    V204452
}

#--------------
#CAT II\Medium
#--------------

#Set system to utilize PAM when changing passwords, V-204405
function V204405() {
    local Regex1="^\s*password\s+substack\s+system-auth\s*"
    local Success="Set system to utilize PAM when changing passwords, per V-204405."
    local Failure="Failed to set the system to utilize PAM when changing passwords, not in compliance with V-204405."

    echo
    grep -E -q "${Regex1}" /etc/pam.d/passwd || echo "password   substack     system-auth" >>/etc/pam.d/passwd
    (grep -E -q "${Regex1}" /etc/pam.d/passwd && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set system to require pwquality when passwords are changed or created, V-204406
function V204406() {
    local Regex1="^\s*password\s+requisite\s+pam_pwquality.so\s+"
    local Regex2="/^\s*password\s+requisite\s+pam_pwquality.so\s+/ { /^\s*password\s+requisite\s+pam_pwquality.so(\s+\S+)*(\s+retry=[0-9]+)(\s+.*)?$/! s/^(\s*password\s+requisite\s+pam_pwquality.so\s+)(.*)$/\1retry=3 \2/ }"
    local Regex3="^(\s*)password\s+requisite\s+\s*pam_pwquality.so\s*retry=3\s*$"
    local Success="Set system to require pwquality when passwords are changed or created, per V-204406."
    local Failure="Failed to set the system to require pwquality when passwords are changed or created, not in compliance V-204406."

    echo
    (grep -E -q "${Regex1}" /etc/pam.d/system-auth-local && sed -ri "${Regex2}" /etc/pam.d/system-auth-local) || echo "password    requisite      pam_pwquality.so retry=3" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex3}" /etc/pam.d/system-auth && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set passwords to require a number of uppercase characters, V-204407
function V204407() {
    local Regex1="^(\s*)#\s*ucredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*ucredit\s*=\s*\S+(\s*#.*)?\s*$/ucredit = -1\2/"
    local Regex3="^(\s*)ucredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)ucredit\s*=\s*\S+(\s*#.*)?\s*$/ucredit = -1\2/"
    local Regex5="^(\s*)ucredit\s*=\s*-1\s*$"
    local Success="Password is set to require a number of uppercase characters, per V-204407"
    local Failure="Password isn't set to require a number of uppercase characters, not in compliance with V-204407."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "ucredit = -1" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set password to require a number of lowercase characters, V-204408
function V204408() {
    local Regex1="^(\s*)#\s*lcredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*lcredit\s*=\s*\S+(\s*#.*)?\s*$/lcredit = -1\2/"
    local Regex3="^(\s*)lcredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)lcredit\s*=\s*\S+(\s*#.*)?\s*$/lcredit = -1\2/"
    local Regex5="^(\s*)lcredit\s*=\s*-1\s*$"
    local Success="Password is set to require a number of lowercase characters, per V-204408"
    local Failure="Password isn't set to require a number of lowercase characters, not in compliance with V-204408."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "ucredit = -1" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set password to require a number of numerical characters, V-204409
function V204409() {
    local Regex1="^(\s*)#\s*dcredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*dcredit\s*=\s*\S+(\s*#.*)?\s*$/dcredit = -1\2/"
    local Regex3="^(\s*)dcredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)dcredit\s*=\s*\S+(\s*#.*)?\s*$/dcredit = -1\2/"
    local Regex5="^(\s*)dcredit\s*=\s*-1\s*$"
    local Success="Password is set to require a number of numerical characters, per V-204409"
    local Failure="Password isn't set to require a number of numerical characters, not in compliance with V-204409."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "ucredit = -1" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set password to require a number of special characters, V-204410
function V204410() {
    local Regex1="^(\s*)#\s*ocredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*ocredit\s*=\s*\S+(\s*#.*)?\s*$/ocredit = -1\2/"
    local Regex3="^(\s*)ocredit\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)ocredit\s*=\s*\S+(\s*#.*)?\s*$/ocredit = -1\2/"
    local Regex5="^(\s*)ocredit\s*=\s*-1\s*$"
    local Success="Password is set to require a number of special characters, per V-204410"
    local Failure="Password isn't set to require a number of special characters, not in compliance with V-204410."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "ucredit = -1" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set min number of characters changed from old password, V-204411
function V204411() {
    local Regex1="^(\s*)#\s*difok\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*difok\s*=\s*\S+(\s*#.*)?\s*$/\difok = 8\2/"
    local Regex3="^(\s*)difok\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)difok\s*=\s*\S+(\s*#.*)?\s*$/\difok = 8\2/"
    local Regex5="^(\s*)difok\s*=\s*8\s*$"
    local Success="Set so a min number of 8 characters are changed from the old password, per V-204411"
    local Failure="Failed to set the password to use a min number of 8 characters are changed from the old password, not in compliance with V-204411"

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "difok = 8" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set min required classes of characters for a new password, V-204412
function V204412() {
    local Regex1="^(\s*)#\s*minclass\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*minclass\s*=\s*\S+(\s*#.*)?\s*$/\minclass = 4\2/"
    local Regex3="^(\s*)minclass\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)minclass\s*=\s*\S+(\s*#.*)?\s*$/\minclass = 4\2/"
    local Regex5="^(\s*)minclass\s*=\s*4\s*$"
    local Success="Password set to use a min number of 4 character classes in a new password, per V-204412."
    local Failure="Failed to set password to use a min number of 4 character classes in a new password, not in compliance with V-204412."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "minclass = 4" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set max number of characters that can repeat, V-204413
function V204413() {
    local Regex1="^(\s*)#\s*maxrepeat\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*maxrepeat\s*=\s*\S+(\s*#.*)?\s*$/\maxrepeat = 3\2/"
    local Regex3="^(\s*)maxrepeat\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)maxrepeat\s*=\s*\S+(\s*#.*)?\s*$/\maxrepeat = 3\2/"
    local Regex5="^(\s*)maxrepeat\s*=\s*3\s*$"
    local Success="Passwords are set to only allow 3 repeat characters in a new password, per V-204413."
    local Failure="Failed to set passwords to only allow 3 repeat characters in a new password, not in compliance with V-204413."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "maxrepeat = 3" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set max number of characters of the same class that can repeat, V-204414
function V204414() {
    local Regex1="^(\s*)#\s*maxclassrepeat\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*maxclassrepeat\s*=\s*\S+(\s*#.*)?\s*$/\maxclassrepeat = 4\2/"
    local Regex3="^(\s*)maxclassrepeat\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)maxclassrepeat\s*=\s*\S+(\s*#.*)?\s*$/\maxclassrepeat = 4\2/"
    local Regex5="^(\s*)maxclassrepeat\s*=\s*4\s*$"
    local Success="Passwords are set to only allow 4 characters of the same class to repeat in a new password, per V-204414."
    local Failure="Failed to set passwords only allow 4 repeat characters of the same class in a new password, not in compliance with V-204414."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "maxclassrepeat = 4" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set passwords to use SHA512, V-204415
function V204415() {
    local Regex1="^\s*password\s+sufficient\s+pam_unix.so\s*"
    local Regex2="s/^\s*password\s+sufficient\s+pam_unix.so\s*"
    local Regex3="password    sufficient    pam_unix.so sha512 shadow try_first_pass use_authtok"
    local Regex4="^(\s*)password\s+sufficient\s+\s*pam_unix.so\s*sha512\s*shadow\s*try_first_pass\s*use_authtok\s*$"
    local Success="Passwords are set to use SHA512 encryption, per V-204415."
    local Failure="Failed to set passwords to use SHA512 encryption, not in compliance with V-204415."

    echo
    (grep -E -q "${Regex1}" /etc/pam.d/system-auth-local && sed -ri "${Regex2}.*$/${Regex3}/" /etc/pam.d/system-auth-local) || echo "${Regex3}" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex1}" /etc/pam.d/password-auth-local && sed -ri "${Regex2}.*$/${Regex3}/" /etc/pam.d/password-auth-local) || echo "${Regex3}" >>/etc/pam.d/password-auth-local
    ( (grep -E -q "${Regex4}" /etc/pam.d/password-auth && grep -E -q "${Regex4}" /etc/pam.d/system-auth) && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set system to create SHA512 hashed passwords, V-204416
function V204416() {
    local Regex1="^(\s*)ENCRYPT_METHOD\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)ENCRYPT_METHOD\s*\S+(\s*#.*)?\s*$/ENCRYPT_METHOD SHA512\2/"
    local Regex3="^\s*ENCRYPT_METHOD\s*SHA512\s*.*$"
    local Success="Passwords are set to be created with SHA512 hash, per V-204416."
    local Failure="Failed to set passwords to be created with SHA512 hash, not in compliance with V-204416."

    echo
    (grep -E -q "${Regex1}" /etc/login.defs && sed -ri "${Regex2}" /etc/login.defs) || echo "ENCRYPT_METHOD SHA512" >>/etc/login.defs
    (grep -E -q "${Regex3}" /etc/login.defs && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set system to store only encrypted representations of passwords in SHA512, V-204417
function V204417() {
    local Regex1="^(\s*)#\s*crypt_style\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*crypt_style\s*=\s*\S+(\s*#.*)?\s*$/crypt_style = sha512\2/"
    local Regex3="^(\s*)crypt_style\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)crypt_style\s*=\s*\S+(\s*#.*)?\s*$/crypt_style = sha512\2/"
    local Regex5="^(\s*)crypt_style\s*=\s*sha512\s*$"
    local Success="Admin utilities are configured to store only encrypted SHA512 passwords, per V-204417."
    local Failure="Failed to set admin utilities are configured to store only encrypted SHA512 passwords, not in compliance with V-204417."

    echo
    ( (grep -E -q "${Regex1}" /etc/libuser.conf && sed -ri "${Regex2}" /etc/libuser.conf) || (grep -E -q "${Regex3}" /etc/libuser.conf && sed -ri "${Regex4}" /etc/libuser.conf)) || echo "crypt_style = sha512" >>/etc/libuser.conf
    (grep -E -q "${Regex5}" /etc/libuser.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set password min lifetome to 1 day, V-204418
function V204418() {
    local Regex1="^(\s*)PASS_MIN_DAYS\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)PASS_MIN_DAYS\s+\S+(\s*#.*)?\s*$/\PASS_MIN_DAYS 1\2/"
    local Regex3="^(\s*)PASS_MIN_DAYS\s*1\s*$"
    local Success="Passwords are set to have a minimum lifetime of 1 day, per V-204418."
    local Failure="Failed to set passwords to have a minimum lifetime of 1 day, not in compliance with V-204418."

    echo
    (grep -E -q "${Regex1}" /etc/login.defs && sed -ri "${Regex2}" /etc/login.defs) || echo "PASS_MIN_DAYS 1" >>/etc/login.defs
    getent passwd | cut -d ':' -f 1 | xargs -n1 chage --mindays 1
    (grep -E -q "${Regex3}" /etc/login.defs && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set password max lifetime to 60 days, V-204420, disabled due to able to break some build automaiton.
function V204420() {
    local Regex1="^(\s*)PASS_MAX_DAYS\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)PASS_MAX_DAYS\s+\S+(\s*#.*)?\s*$/\PASS_MAX_DAYS 60\2/"
    local Regex3="^(\s*)PASS_MAX_DAYS\s*60\s*$"
    local Success="Passwords are set to have a maximum lifetime to 60 days, per V-204420."
    local Failure="Failed to set passwords to have a maximum lifetime to 60 days, not in compliance with V-204420."

    echo
    grep -E -q "${Regex1}" /etc/login.defs && sed -ri "${Regex2}" /etc/login.defs || echo "PASS_MAX_DAYS 60" >>/etc/login.defs
    getent passwd | cut -d ':' -f 1 | xargs -n1 chage --maxdays 60
    grep -E -q "${Regex3}" /etc/login.defs && echo "${Success}" || {
        echo "${Failure}"
    }
}

#Limit password reuse to 5, V-204422
function V204422() {
    local Regex1="^\s*password\s+requisite\s+\s*pam_pwhistory.so\s*use_authtok\s*remember=\S+(\s*#.*)?(\s+.*)$"
    local Regex2="s/^(\s*)password\s+requisite\s+\s*pam_pwhistory.so\s*use_authtok\s*remember=\S+(\s*#.*)\s*retry=\S+(\s*#.*)?\s*S/\password\s+requisite\s+\s*pam_pwhistory.so\s*use_authtok\s*remember=5\s*retry=3\2/"
    local Regex3="^(\s*)password\s+requisite\s+\s*pam_pwhistory.so\s*use_authtok\s*remember=5\s*retry=3\s*$"
    local Success="System is set to keep password history of the last 5 passwords, per V-204422."
    local Failure="Failed to set the system to keep password history of the last 5 passwords, not in compliance with V-204422."

    echo
    (grep -E -q "${Regex1}" /etc/pam.d/system-auth-local && sed -ri "${Regex2}" /etc/pam.d/system-auth-local) || echo "password    requisite     pam_pwhistory.so use_authtok remember=5 retry=3" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex1}" /etc/pam.d/password-auth-local && sed -ri "${Regex2}" /etc/pam.d/password-auth-local) || echo "password    requisite     pam_pwhistory.so use_authtok remember=5 retry=3" >>/etc/pam.d/password-auth-local
    ( (grep -E -q "${Regex3}" /etc/pam.d/password-auth && grep -E -q "${Regex3}" /etc/pam.d/system-auth) && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set min 15 character password length, V-204423
function V204423() {
    local Regex1="^(\s*)#\s*minlen\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#\s*minlen\s*=\s*\S+(\s*#.*)?\s*$/\minlen = 15\2/"
    local Regex3="^(\s*)minlen\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)minlen\s*=\s*\S+(\s*#.*)?\s*$/\minlen = 15\2/"
    local Regex5="^(\s*)minlen\s*=\s*15\s*$"
    local Success="Passwords are set to have a min of 15 characters, per V-204423."
    local Failure="Failed to set passwords to use a min of 15 characters, not in compliance with V-204423."

    echo
    ( (grep -E -q "${Regex1}" /etc/security/pwquality.conf && sed -ri "${Regex2}" /etc/security/pwquality.conf) || (grep -E -q "${Regex3}" /etc/security/pwquality.conf && sed -ri "${Regex4}" /etc/security/pwquality.conf)) || echo "crypt_style = sha512" >>/etc/security/pwquality.conf
    (grep -E -q "${Regex5}" /etc/security/pwquality.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Disable account identifiers, V-204426
function V204426() {
    local Regex1="^(\s*)INACTIVE=\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)INACTIVE=\S+(\s*#.*)?\s*$/\INACTIVE=35\2/"
    local Regex3="^(\s*)INACTIVE=35\s*$"
    local Success="Account identifiers are disabled once the password expires, per V-204426."
    local Failure="Failed to set account identifiers are disabled once the password expires, not in compliance with V-204426."

    echo
    (grep -E -q "${Regex1}" /etc/default/useradd && sed -ri "${Regex2}" /etc/default/useradd) || echo "INACTIVE=0" >>/etc/default/useradd
    (grep -E -q "${Regex3}" /etc/default/useradd && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set system to lock account after 3 failed logon attempts within 15 mins even deny root, V-204427 & V-204428
function V204427() {
    local Regex1="^\s*auth\s+required\s+pam_faillock.so\s*"
    local Regex2="s/^\s*auth\s+\s*\s*\s*required\s+pam_faillock.so\s*"
    local Regex3="auth        required      pam_faillock.so preauth silent audit deny=3 even_deny_root fail_interval=900 unlock_time=900"
    local Regex4="^\s*auth\s+sufficient\s+pam_unix.so\s*"
    local Regex5="s/^\s*auth\s+\s*\s*\s*sufficient\s+pam_unix.so\s*"
    local Regex6="auth        sufficient    pam_unix.so try_first_pass"
    local Regex7="^\s*auth\s+\[default=die\]\s+pam_faillock.so\s*"
    local Regex8="s/^\s*auth\s+\s*\s*\s*\[default=die\]\s+pam_faillock.so\s*"
    local Regex9="auth        [default=die] pam_faillock.so authfail audit deny=3 even_deny_root fail_interval=900 unlock_time=900"
    local Regex10="^\s*account\s+required\s+pam_faillock.so\s*"
    local Regex11="s/^\s*account\s+\s*\s*\s*required\s+pam_faillock.so\s*"
    local Regex12="account     required      pam_faillock.so"
    local Regex13="^(\s*)auth\s+required\s+\s*pam_faillock.so\s*preauth\s*silent\s*audit\s*deny=3\s*even_deny_root\s*fail_interval=900\s*unlock_time=900\s*$"
    local Regex14="^(\s*)auth\s+sufficient\s+\s*pam_unix.so\s*try_first_pass\s*$"
    local Regex15="^(\s*)auth\s+\[default=die\]\s+pam_faillock.so\s*authfail\s*audit\s*deny=3\s*even_deny_root\s*fail_interval=900\s*unlock_time=900\s*$"
    local Regex16="^(\s*)account\s+required\s+\s*pam_faillock.so\s*$"
    local Success="Account lockout time after 3 failed logon attempts set to 15 mins even deny root, per V-204427 & V-204428."
    local Failure="Failed to set account lockout time after 3 failed logon attempts set to 15 mins even deny root, not in compliance with V-204427 & V-204428."

    echo
    (grep -E -q "${Regex1}" /etc/pam.d/system-auth-local && sed -ri "${Regex2}.*$/${Regex3}/" /etc/pam.d/system-auth-local) || echo "${Regex3}" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex1}" /etc/pam.d/password-auth-local && sed -ri "${Regex2}.*$/${Regex3}/" /etc/pam.d/password-auth-local) || echo "${Regex3}" >>/etc/pam.d/password-auth-local
    (grep -E -q "${Regex4}" /etc/pam.d/system-auth-local && sed -ri "${Regex5}.*$/${Regex6}/" /etc/pam.d/system-auth-local) || echo "${Regex6}" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex4}" /etc/pam.d/password-auth-local && sed -ri "${Regex5}.*$/${Regex6}/" /etc/pam.d/password-auth-local) || echo "${Regex6}" >>/etc/pam.d/password-auth-local
    (grep -E -q "${Regex7}" /etc/pam.d/system-auth-local && sed -ri "${Regex8}.*$/${Regex9}/" /etc/pam.d/system-auth-local) || echo "${Regex9}" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex7}" /etc/pam.d/password-auth-local && sed -ri "${Regex8}.*$/${Regex9}/" /etc/pam.d/password-auth-local) || echo "${Regex9}" >>/etc/pam.d/password-auth-local
    (grep -E -q "${Regex10}" /etc/pam.d/system-auth-local && sed -ri "${Regex11}.*$/${Regex12}/" /etc/pam.d/system-auth-local) || echo "${Regex12}" >>/etc/pam.d/system-auth-local
    (grep -E -q "${Regex10}" /etc/pam.d/password-auth-local && sed -ri "${Regex11}.*$/${Regex12}/" /etc/pam.d/password-auth-local) || echo "${Regex12}" >>/etc/pam.d/password-auth-local

    (grep -E -q "${Regex13}" /etc/pam.d/password-auth && grep -E -q "${Regex13}" /etc/pam.d/system-auth) || {
        echo "${Failure}"
    }
    (grep -E -q "${Regex14}" /etc/pam.d/password-auth && grep -E -q "${Regex14}" /etc/pam.d/system-auth) || {
        echo "${Failure}"
    }
    (grep -E -q "${Regex15}" /etc/pam.d/password-auth && grep -E -q "${Regex15}" /etc/pam.d/system-auth) || {
        echo "${Failure}"
    }
    ( (grep -E -q "${Regex16}" /etc/pam.d/password-auth && grep -E -q "${Regex16}" /etc/pam.d/system-auth) && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set delay between failed logon attenpts, V-204431
function V204431() {
    local Regex1="^(\s*)FAIL_DELAY\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)FAIL_DELAY\s+\S+(\s*#.*)?\s*$/\FAIL_DELAY 4\2/"
    local Regex3="^(\s*)FAIL_DELAY\s*4\s*$"
    local Success="Set a 4 sec delay between failed logon attempts, per V-204431."
    local Failure="Failed to set a 4 sec delay between failed logon attempts, not in compliance with V-204431."

    echo
    (grep -E -q "${Regex1}" /etc/login.defs && sed -ri "${Regex2}" /etc/login.defs) || echo "FAIL_DELAY 4" >>/etc/login.defs
    (grep -E -q "${Regex3}" /etc/login.defs && echo "${Success}") || {
        echo "${Failure}"
    }
}

# Set SSH HostbasedAuthentication to no, V-204435
function V204435() {
    local Regex1="^(\s*)#HostbasedAuthentication\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#HostbasedAuthentication\s+\S+(\s*#.*)?\s*$/\HostbasedAuthentication no\2/"
    local Regex3="^(\s*)HostbasedAuthentication\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)HostbasedAuthentication\s+\S+(\s*#.*)?\s*$/\HostbasedAuthentication no\2/"
    local Regex5="^(\s*)HostbasedAuthentication\s*no\s*$"
    local Success="Set OS to not allow non-certificate trusted host SSH to log onto the system, per V-204435."
    local Failure="Failed to set OS to not allow non-certificate trusted host SSH to log onto the system, not in compliance with V-204435."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "HostbasedAuthentication no" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set system to require authentication upon booting into single-user and maintenance modes, V-204437
function V204437() {
    local Regex1="^\s*ExecStart"
    local Regex2="s/(^[[:space:]]*ExecStart[[:space:]]*=[[:space:]]*).*$/\1-\/bin\/sh -c \"\/usr\/sbin\/sulogin; \/usr\/bin\/systemctl --fail --no-block default\"/"
    local Regex3="^\s*ExecStart=-\/bin\/sh\s*-c\s*\"\/usr\/sbin\/sulogin;\s*\/usr\/bin\/systemctl\s*--fail\s*--no-block\s*default\""
    local Success="Set system to require authentication upon booting into single-user and maintenance modes, per V-204437."
    local Failure="Failed to set the system to require authentication upon booting into single-user and maintenance modes, not in compliance V-204437."

    echo
    (grep -E -q "${Regex1}" /usr/lib/systemd/system/rescue.service && sed -ri "${Regex2}" /usr/lib/systemd/system/rescue.service) || echo "ExecStart=-/bin/sh -c \"/usr/sbin/sulogin; /usr/bin/systemctl --fail --no-block default\"" >>/usr/lib/systemd/system/rescue.service
    (grep -E -q "${Regex3}" /usr/lib/systemd/system/rescue.service && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Disable USB mass storage, V-204449
function V204449() {
    local Regex1="^\s*install\s*usb-storage\s*/bin/true\s*"
    local Regex2="s/^\s*install\s*usb-storage\s*.*$/install usb-storage \/bin\/true/"
    local Regex3="install usb-storage /bin/true"
    local Success="Configured to disable USB mass storage, per V-204449."
    local Failure="Failed to configure system to disable USB mass storage, not in compliance with V-204449."

    if [ -f "/etc/modprobe.d/usb-storage.conf" ]; then
        (grep -E -q "${Regex1}" /etc/modprobe.d/usb-storage.conf && sed -ri "${Regex2}" /etc/modprobe.d/usb-storage.conf) || echo "${Regex3}" >>/etc/modprobe.d/usb-storage.conf
    else
        echo "${Regex3}" >>/etc/modprobe.d/usb-storage.conf
    fi

    echo
    ( grep -E -q "${Regex1}" /etc/modprobe.d/usb-storage.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Disable DCCP kernel module, V-204450.
function V204450() {
    local Regex1="^(\s*)#install\s*dccp\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#install\s*dccp\s+\S+(\s*#.*)?\s*$/\install dccp \/bin\/true\2/"
    local Regex3="^(\s*)install\s*dccp\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)install\s*dccp\s+\S+(\s*#.*)?\s*$/\install dccp \/bin\/true\2/"
    local Regex5="^(\s*)install\s*dccp\s*/bin/true?\s*$"
    local Regex6="^(\s*)blacklist\s*dccp(\s*#.*)?\s*$"
    local Regex7="s/^(\s*)blacklist\s*dccp(\s*#.*)?\s*$/\blacklist dccp\2/"
    local Regex8="^(\s*)blacklist\s*dccp?\s*$"
    local Success="Disabled DCCP on the system, per V-204450."
    local Failure="Failed to disable DCCP on the system, not in compliance V-204450."

    if [ -f "/etc/modprobe.d/dccp.conf" ]; then
        ( (grep -E -q "${Regex1}" /etc/modprobe.d/dccp.conf && sed -ri "${Regex2}" /etc/modprobe.d/dccp.conf) || (grep -E -q "${Regex3}" /etc/modprobe.d/dccp.conf && sed -ri "${Regex4}" /etc/modprobe.d/dccp.conf)) || echo "install dccp /bin/true" >>/etc/modprobe.d/dccp.conf
    else
        echo -e "install dccp /bin/true" >>/etc/modprobe.d/dccp.conf
    fi

    if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
        (grep -E -q "${Regex6}" /etc/modprobe.d/blacklist.conf && sed -ri "${Regex7}" /etc/modprobe.d/blacklist.conf) || echo "blacklist dccp" >>/etc/modprobe.d/blacklist.conf
    else
        echo -e "blacklist dccp" >>/etc/modprobe.d/blacklist.conf
    fi

    echo
    (grep -E -q "${Regex5}" /etc/modprobe.d/dccp.conf && echo "${Success}") || {
        echo "${Failure}"
    }
    echo
    (grep -E -q "${Regex8}" /etc/modprobe.d/blacklist.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Disable system automounter, V-204451
function V204451() {
    local Success="Disabled AUTOFS on the system, per V-204451."
    local Failure="Failed to disabled AUTOFS on the system, not in compliance with V-204451."
    local Notinstalled="AUTOFS was not installed on the system.  Disabled by default, per V-204451."

    echo
    if ! systemctl list-unit-files --full -all | grep -E -q '^autofs'; then
        echo "${Notinstalled}"
    else
        systemctl stop autofs
        systemctl disable autofs
        ( (systemctl status autofs | grep -E -q "dead") && echo "${Success}") || {
            echo "${Failure}"
        }
    fi
}

#Set system to apply the most restricted default permissions for all authenticated users, V-204457
function V204457() {
    local Regex1="^(\s*)UMASK\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)UMASK\s+\S+(\s*#.*)?\s*$/\1UMASK           077\2/"
    local Regex3="^(\s*)UMASK\s*077\s*$"
    local Success="Set system to apply the most restricted default permissions for all authenticated users, per V-204457."
    local Failure="Failed to set the system to apply the most restricted default permissions for all authenticated users, not in compliance with V-204457."

    echo
    (grep -E -q "${Regex1}" /etc/login.defs && sed -ri "${Regex2}" /etc/login.defs) || echo "UMASK           077" >>/etc/login.defs
    (grep -E -q "${Regex3}" /etc/login.defs && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set system create a home directory on login, V-204466
function V204466() {
    local Regex1="^(\s*)CREATE_HOME\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)CREATE_HOME\s+\S+(\s*#.*)?\s*$/\CREATE_HOME     yes\2/"
    local Regex3="^(\s*)CREATE_HOME\s*yes\s*$"
    local Success="Set system create a home directory on login, per V-204466."
    local Failure="Failed to set the system create a home directory on login, not in compliance with V-204466."

    echo
    (grep -E -q "${Regex1}" /etc/login.defs && sed -ri "${Regex2}" /etc/login.defs) || echo "CREATE_HOME     yes" >>/etc/login.defs
    (grep -E -q "${Regex3}" /etc/login.defs && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set the auditd service is active, V-204503
function V204503() {
    local Success="Set the auditd service is active, per V-204503."
    local Failure="Failed to set the auditd service to active, not in compliance with V-204503."

    echo

    if ! systemctl list-unit-files --full -all | grep -E -q '^audit.service'; then
        yum install -q -y audit &>/dev/null
    else
        if systemctl is-active auditd.service | grep -E -q "active"; then
            systemctl enable auditd.service
        else
            systemctl start auditd.service
            systemctl enable auditd.service
        fi
    fi
    ( (systemctl is-active auditd.service | grep -E -q "active") && echo "${Success}") || {
    echo "${Failure}"
    }
}

#Set SSH to use FIPS, V-204578
function V204578() {
    local Regex1="^(\s*)Ciphers\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)Ciphers\s+\S+(\s*#.*)?\s*$/\Ciphers aes128-ctr,aes192-ctr,aes256-ctr\2/"
    local Regex3="^(\s*)Ciphers\s*aes128-ctr,aes192-ctr,aes256-ctr\s*$"
    local Success="Set SSH to use FIPS, per V-204578."
    local Failure="Failed to set SSH to use FIPS, not in compliance V-204578."

    echo
    (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || echo "Ciphers aes128-ctr,aes192-ctr,aes256-ctr" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex3}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set timeout period, V-204587
function V204587() {
    local Regex1="^(\s*)#ClientAliveInterval\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#ClientAliveInterval\s+\S+(\s*#.*)?\s*$/\ClientAliveInterval 600\2/"
    local Regex3="^(\s*)ClientAliveInterval\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)ClientAliveInterval\s+\S+(\s*#.*)?\s*$/\ClientAliveInterval 600\2/"
    local Regex5="^(\s*)ClientAliveInterval\s*600?\s*$"
    local Success="Set SSH user timeout period to 600secs, per V-204587."
    local Failure="Failed to set SSH user timeout period to 600secs, not in compliance V-204587."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "ClientAliveInterval 600" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set terminate user session after timeout, V-204589
function V204589() {
    local Regex1="^(\s*)#ClientAliveCountMax\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#ClientAliveCountMax\s+\S+(\s*#.*)?\s*$/\ClientAliveCountMax 0\2/"
    local Regex3="s/^(\s*)ClientAliveCountMax\s+\S+(\s*#.*)?\s*$/\ClientAliveCountMax 0\2/"
    local Regex4="^(\s*)ClientAliveCountMax\s*0?\s*$"
    local Success="Set SSH user sesstions to terminate after session timeout, per V-204589."
    local Failure="Failed to set SSH user sesstions to terminate after session timeout, not in compliance V-204589."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex4}" /etc/ssh/sshd_config && sed -ri "${Regex3}" /etc/ssh/sshd_config)) || echo "ClientAliveCountMax 0" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex4}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set to not allow authentication using known host, V-204590
function V204590() {
    local Regex1="^(\s*)#IgnoreRhosts\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#IgnoreRhosts\s+\S+(\s*#.*)?\s*$/\IgnoreRhosts yes\2/"
    local Regex3="^(\s*)IgnoreRhosts\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)IgnoreRhosts\s+\S+(\s*#.*)?\s*$/\IgnoreRhosts yes\2/"
    local Regex5="^(\s*)IgnoreRhosts\s*yes?\s*$"
    local Success="Set SSH to not allow rhosts authentication, per V-204590."
    local Failure="Failed to set SSH to not allow rhosts authentication, not in compliance V-204590."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "IgnoreRhosts yes" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set to provide feedback on last account access, V-204591
function V204591() {
    local Regex1="^(\s*)#PrintLastLog\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#PrintLastLog\s+\S+(\s*#.*)?\s*$/\PrintLastLog yes\2/"
    local Regex3="^(\s*)PrintLastLog\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)PrintLastLog\s+\S+(\s*#.*)?\s*$/\PrintLastLog yes\2/"
    local Regex5="^(\s*)PrintLastLog\s*yes?\s*$"
    local Success="Set SSH to inform users of when the last time their account connected, per V-204591."
    local Failure="Failed to set SSH to inform users of when the last time their account connected, not in compliance V-204591."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "PrintLastLog yes" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set SSH to prevent root logon, V-204592
function V204592() {
    local Regex1="^(\s*)#PermitRootLogin\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#PermitRootLogin\s+\S+(\s*#.*)?\s*$/\PermitRootLogin no\2/"
    local Regex3="^(\s*)PermitRootLogin\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)PermitRootLogin\s+\S+(\s*#.*)?\s*$/\PermitRootLogin no\2/"
    local Regex5="^(\s*)PermitRootLogin\s*no?\s*$"
    local Success="Set SSH to not allow connections from root, per V-204592."
    local Failure="Failed to set SSH to not allow connections from root, not in compliance V-204592."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "PermitRootLogin no" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set to not allow authentication using known host, V-204593
function V204593 {
    local Regex1="^(\s*)#IgnoreUserKnownHosts\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#IgnoreUserKnownHosts\s+\S+(\s*#.*)?\s*$/\IgnoreUserKnownHosts yes\2/"
    local Regex3="^(\s*)IgnoreUserKnownHosts\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)IgnoreUserKnownHosts\s+\S+(\s*#.*)?\s*$/\IgnoreUserKnownHosts yes\2/"
    local Regex5="^(\s*)IgnoreUserKnownHosts\s*yes?\s*$"
    local Success="Set SSH to not allow authentication using known host authentication, per V-204593."
    local Failure="Failed to set SSH to not allow authentication using known host authentication, not in compliance V-204593."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "IgnoreUserKnownHosts yes" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set SSH to only use MACs using FIPS, V-204595
function V204595() {
    local Regex1="^(\s*)MACs\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)MACs\s+\S+(\s*#.*)?\s*$/\MACs hmac-sha2-256,hmac-sha2-512\2/"
    local Regex3="^(\s*)MACs\s*hmac-sha2-256,hmac-sha2-512\s*$"
    local Success="Set SSH to only use MACs using FIPS, per V-204595."
    local Failure="Failed to set SSH only use MACs using FIPS, not in compliance V-204595."

    echo
    (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || echo "MACs hmac-sha2-256,hmac-sha2-512" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex3}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Do not permit GSSAPI auth, V-204598
function V204598() {
    local Regex1="^(\s*)GSSAPIAuthentication\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)GSSAPIAuthentication\s+\S+(\s*#.*)?\s*$/\GSSAPIAuthentication no\2/"
    local Regex3="^(\s*)GSSAPIAuthentication\s*no?\s*$"
    local Success="Set SSH to not allow authentication using GSSAPI authentication, per V-204598."
    local Failure="Failed to set SSH to not allow authentication using GSSAPI authentication, not in compliance V-204598."

    echo
    (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || echo "GSSAPIAuthentication no" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex3}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Disable Kerberos over SSH, V-204599
function V204599() {
    local Regex1="^(\s*)#KerberosAuthentication\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#KerberosAuthentication\s+\S+(\s*#.*)?\s*$/\KerberosAuthentication no\2/"
    local Regex3="^(\s*)KerberosAuthentication\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)KerberosAuthentication\s+\S+(\s*#.*)?\s*$/\KerberosAuthentication no\2/"
    local Regex5="^(\s*)KerberosAuthentication\s*no?\s*$"
    local Success="Set SSH to not allow authentication using KerberosAuthentication authentication, per V-204599."
    local Failure="Failed to set SSH to not allow authentication using KerberosAuthentication authentication, not in compliance V-204599."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "KerberosAuthentication no" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set SSH to perform strict mode checking of home dir configuraiton files, V-204600
function V204600() {
    local Regex1="^(\s*)#StrictModes\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#StrictModes\s+\S+(\s*#.*)?\s*$/\StrictModes yes\2/"
    local Regex3="^(\s*)StrictModes\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)StrictModes\s+\S+(\s*#.*)?\s*$/\StrictModes yes\2/"
    local Regex5="^(\s*)StrictModes\s*yes?\s*$"
    local Success="Set SSH to perform strict mode checking of the home directory configuration files, per V-204600."
    local Failure="Failed to set SSH to perform strict mode checking of the home directory configuration files, not in compliance V-204600."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "StrictModes yes" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set SSH to perform privilege separation, V-204602
function V204602() {
    local Regex1="^(\s*)#Compression\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#Compression\s+\S+(\s*#.*)?\s*$/\Compression delayed\2/"
    local Regex3="^(\s*)Compression\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)Compression\s+\S+(\s*#.*)?\s*$/\Compression delayed\2/"
    local Regex5="^(\s*)Compression\s*delayed?\s*$"
    local Success="Set SSH to only allow compression after successful authentication, per V-204602."
    local Failure="Failed to set SSH to only allow compression after successful authentication, not in compliance V-204602."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "Compression delayed" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set OS to not accept ICMP redirects, V-204614
function V204614() {
    local Regex1="^(\s*)#net.ipv4.conf.default.accept_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#net.ipv4.conf.default.accept_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.default.accept_redirects = 0\2/"
    local Regex3="^(\s*)net.ipv4.conf.default.accept_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)net.ipv4.conf.default.accept_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.default.accept_redirects = 0\2/"
    local Regex5="^(\s*)net.ipv4.conf.default.accept_redirects\s*=\s*0?\s*$"
    local Success="Set system to not accept ICMP redirects on IPv4, per V-204614."
    local Failure="Failed to set the system to not accept ICMP redirects on IPv4, not in compliance V-204614."

    echo
    ( (grep -E -q "${Regex1}" /etc/sysctl.conf && sed -ri "${Regex2}" /etc/sysctl.conf) || (grep -E -q "${Regex3}" /etc/sysctl.conf && sed -ri "${Regex4}" /etc/sysctl.conf)) || echo "net.ipv4.conf.default.accept_redirects = 0" >>/etc/sysctl.conf
    (grep -E -q "${Regex5}" /etc/sysctl.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set OS to ignore ICMP redirects, V-204615
function V204615() {
    local Regex1="^(\s*)#net.ipv4.conf.all.accept_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#net.ipv4.conf.all.accept_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.all.accept_redirects = 0\2/"
    local Regex3="^(\s*)net.ipv4.conf.all.accept_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)net.ipv4.conf.all.accept_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.all.accept_redirects = 0\2/"
    local Regex5="^(\s*)net.ipv4.conf.all.accept_redirects\s*=\s*0?\s*$"
    local Success="Set system to ignore IPv4 ICMP redirect messages, per V-204615."
    local Failure="Failed to set the system to ignore IPv4 ICMP redirect messages, not in compliance V-204615."

    echo
    ( (grep -E -q "${Regex1}" /etc/sysctl.conf && sed -ri "${Regex2}" /etc/sysctl.conf) || (grep -E -q "${Regex3}" /etc/sysctl.conf && sed -ri "${Regex4}" /etc/sysctl.conf)) || echo "net.ipv4.conf.all.accept_redirects = 0" >>/etc/sysctl.conf
    (grep -E -q "${Regex5}" /etc/sysctl.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set OS to not allow interfaces to perform ICMP redirects, V-204616
function V204616() {
    local Regex1="^(\s*)#net.ipv4.conf.default.send_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#net.ipv4.conf.default.send_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.default.send_redirects = 0\2/"
    local Regex3="^(\s*)net.ipv4.conf.default.send_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)net.ipv4.conf.default.send_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.default.send_redirects = 0\2/"
    local Regex5="^(\s*)net.ipv4.conf.default.send_redirects\s*=\s*0?\s*$"
    local Success="Set system to not peform ICMP redirects on IPv4 by default, per V-204616."
    local Failure="Failed to set the system to not peform ICMP redirects on IPv4 by default, not in compliance V-204616."

    echo
    ( (grep -E -q "${Regex1}" /etc/sysctl.conf && sed -ri "${Regex2}" /etc/sysctl.conf) || (grep -E -q "${Regex3}" /etc/sysctl.conf && sed -ri "${Regex4}" /etc/sysctl.conf)) || echo "net.ipv4.conf.default.send_redirects = 0" >>/etc/sysctl.conf
    (grep -E -q "${Regex5}" /etc/sysctl.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set OS to not allow sending ICMP redirects, V-204617
function V204617() {
    local Regex1="^(\s*)#net.ipv4.conf.all.send_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#net.ipv4.conf.all.send_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.all.send_redirects = 0\2/"
    local Regex3="^(\s*)net.ipv4.conf.all.send_redirects\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)net.ipv4.conf.all.send_redirects\s+\S+(\s*#.*)?\s*$/\net.ipv4.conf.all.send_redirects = 0\2/"
    local Regex5="^(\s*)net.ipv4.conf.all.send_redirects\s*=\s*0?\s*$"
    local Success="Set system to not send ICMP redirects on IPv4, per V-204617."
    local Failure="Failed to set the system to not send ICMP redirects on IPv4, not in compliance V-204617."

    echo
    ( (grep -E -q "${Regex1}" /etc/sysctl.conf && sed -ri "${Regex2}" /etc/sysctl.conf) || (grep -E -q "${Regex3}" /etc/sysctl.conf && sed -ri "${Regex4}" /etc/sysctl.conf)) || echo "net.ipv4.conf.all.send_redirects = 0" >>/etc/sysctl.conf
    (grep -E -q "${Regex5}" /etc/sysctl.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Prevent unrestricted mail relaying, V-204619
function V204619() {
    local Regex1="^(\s*)#smtpd_client_restrictions\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#smtpd_client_restrictions\s*=\s*\S+(\s*#.*)?\s*$/\smtpd_client_restrictions = permit_mynetworks,reject\2/"
    local Regex3="^(\s*)smtpd_client_restrictions\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)smtpd_client_restrictions\s*=\s*\S+(\s*#.*)?\s*$/\smtpd_client_restrictions = permit_mynetworks,reject\2/"
    local Regex5="^(\s*)smtpd_client_restrictions\s*=\s*permit_mynetworks,reject?\s*$"
    local Success="Set postfix from being used as an unrestricted mail relay, per V-204619."
    local Failure="Failed to set postfix from being used as an unrestricted mail relay, not in compliance V-204619."
    local NA="Postfix is not installed, V-204619 is Not Applicable."

    echo
    if yum -q list installed postfix &>/dev/null; then
        ( (grep -E -q "${Regex1}" /etc/postfix/main.cf && sed -ri "${Regex2}" /etc/postfix/main.cf) || (grep -E -q "${Regex3}" /etc/postfix/main.cf && sed -ri "${Regex4}" /etc/postfix/main.cf)) || postconf -e 'smtpd_client_restrictions = permit_mynetworks,reject'
        (grep -E -q "${Regex5}" /etc/postfix/main.cf && echo "${Success}") || {
            echo "${Failure}"
        }
    else
        echo "${NA}"
    fi
}

#Set SSH X11 forwarding ensabled, V-204622
function V204622() {
    local Regex1="^(\s*)#X11Forwarding\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#X11Forwarding\s+\S+(\s*#.*)?\s*$/\X11Forwarding no\2/"
    local Regex3="^(\s*)X11Forwarding\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)X11Forwarding\s+\S+(\s*#.*)?\s*$/\X11Forwarding no\2/"
    local Regex5="^(\s*)X11Forwarding\s*no\s*$"
    local Success="Set SSH X11 forwarding ensabled, per V-204622."
    local Failure="Failed to set SSH X11 forwarding ensabled, not in compliance with V-204622."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "X11Forwarding no" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Install pam_pkcs11, V-204631
function V204631() {
    local Success="pam_pkcs11 is installed, per V-204631."
    local Failure="Failed to install pam_pkcs11, not in compliance with V-204631."

    echo
    if yum -q list installed pam_pkcs11 &>/dev/null; then
        echo "${Success}"
    else
        yum install -q -y pam_pkcs11
        ( (yum -q list installed pam_pkcs11 &>/dev/null) && echo "${Success}") || {
            echo "${Failure}"
        }
    fi
}

#Enable OCSP for PKI authentication, V-204633
function V204633() {
    local Regex1="^(\s*)cert_policy\s*=\s*"
    local Regex2="s/^(\s*)cert_policy\s*=\s*"
    local Regex3="    cert_policy = ca, ocsp_on, signature\;"
    local Regex4="^(\s*)cert_policy\s*=\s*ca, ocsp_on, signature\;\s*$"
    local Success="OCSP is enabled on system, per V-204633."
    local Failure="Failed to enable OCSP on the system, not in compliance V-204633."

    echo
    (grep -E -q "${Regex1}" /etc/pam_pkcs11/pam_pkcs11.conf && sed -ri "${Regex2}.*$/${Regex3}/g" /etc/pam_pkcs11/pam_pkcs11.conf)
    (grep -E -q "${Regex4}" /etc/pam_pkcs11/pam_pkcs11.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set SSH X11 forwarding ensabled, V-233307
function V233307() {
    local Regex1="^(\s*)#X11UseLocalhost\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#X11UseLocalhost\s+\S+(\s*#.*)?\s*$/\X11UseLocalhost yes\2/"
    local Regex3="^(\s*)X11UseLocalhost\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)X11UseLocalhost\s+\S+(\s*#.*)?\s*$/\X11UseLocalhost yes\2/"
    local Regex5="^(\s*)X11UseLocalhost\s*yes\s*$"
    local Success="Set SSH X11 forwarding ensabled, per V-233307."
    local Failure="Failed to set SSH X11 forwarding ensabled, not in compliance with V-233307."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "X11UseLocalhost yes" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#System must specify the default "include" dir, V-251703
function V251703() {
    local Regex1="^(\s*)#includedir\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#includedir\s*\S+(\s*#.*)?\s*$/\#includedir   \/etc\/sudoers.d\2/"
    local Regex3="^(\s*)#includedir\s+\/etc\/sudoers.d\s*$"
    local Success="Set system to use the invoking user's password when using sudo, per V-251703."
    local Failure="Failed to set system to use the invoking user's password when using sudo, not in compliance V-251703."

    echo
    (grep -E -q "${Regex1}" /etc/sudoers && sed -ri "${Regex2}" /etc/sudoers) || echo "includedir   /etc/sudoers.d" >>/etc/sudoers
    (grep -E -q "${Regex3}" /etc/sudoers && echo "${Success}") || {
        echo "${Failure}"
    }
}

#System must not be configured to bypass password requirements for privilege escalation, V-251704

#Set authconfig to use custom files for it's settings, V-255928
function V255928() {
    local Regex1="auth        required      pam_faillock.so preauth silent audit deny=3 even_deny_root fail_interval=900 unlock_time=900"
    local Regex2="auth        include       system-auth-ac"
    local Regex3="auth        sufficient    pam_unix.so try_first_pass"
    local Regex4="auth        [default=die] pam_faillock.so authfail audit deny=3 even_deny_root fail_interval=900 unlock_time=900"

    local Regex5="account     required      pam_faillock.so"
    local Regex6="account     include       system-auth-ac"

    local Regex7="password    requisite     pam_pwhistory.so remember=5 retry=3"
    local Regex8="password    requisite     pam_pwquality.so retry=3"
    local Regex9="password    include       system-auth-ac"
    local Regex10="password    sufficient    pam_unix.so sha512 shadow try_first_pass use_authtok"

    local Regex11="session     include       system-auth-ac"

    local Regex12="auth        include       password-auth-ac"
    local Regex13="account     include       password-auth-ac"
    local Regex14="password    include       password-auth-ac"
    local Regex15="session     include       password-auth-ac"

    #Lines for checking/adding system-auth-ac to system-auth-local
    local Regex16="^\s*auth\s+include\s+system-auth-ac\s*"
    local Regex17="s/^\s*auth\s+\s*\s*\s*include\s+system-auth-ac\s*"
    local Regex18="^\s*account\s+include\s+system-auth-ac\s*"
    local Regex19="s/^\s*account\s+include\s+system-auth-ac\s*"
    local Regex20="^\s*password\s+include\s+system-auth-ac\s*"
    local Regex21="s/^\s*password\s+include\s+system-auth-ac\s*"
    local Regex22="^\s*session\s+include\s+system-auth-ac\s*"
    local Regex23="s/^\s*session\s+include\s+system-auth-ac\s*"

    #Lines for checking/adding password-auth-ac to password-auth-local
    local Regex24="^\s*auth\s+include\s+password-auth-ac\s*"
    local Regex25="s/^\s*auth\s+\s*\s*\s*include\s+password-auth-ac\s*"
    local Regex26="^\s*account\s+include\s+password-auth-ac\s*"
    local Regex27="s/^\s*account\s+include\s+password-auth-ac\s*"
    local Regex28="^\s*password\s+include\s+password-auth-ac\s*"
    local Regex29="s/^\s*password\s+include\s+password-auth-ac\s*"
    local Regex30="^\s*session\s+include\s+password-auth-ac\s*"
    local Regex31="s/^\s*session\s+include\s+password-auth-ac\s*"

    #Verification checks
    local Regex32="^(\s*)auth\s+include\s+\s*system-auth-ac\s*$"
    local Regex33="^(\s*)account\s+include\s+\s*system-auth-ac\s*$"
    local Regex34="^(\s*)password\s+include\s+\s*system-auth-ac\s*$"
    local Regex35="^(\s*)session\s+include\s+\s*system-auth-ac\s*$"

    local Regex36="^(\s*)auth\s+include\s+\s*password-auth-ac\s*$"
    local Regex37="^(\s*)account\s+include\s+\s*password-auth-ac\s*$"
    local Regex38="^(\s*)password\s+include\s+\s*password-auth-ac\s*$"
    local Regex39="^(\s*)session\s+include\s+\s*password-auth-ac\s*$"
    local ALSuccess="Removed the lines for 'account  include  password-auth-ac' and  'session  include  password-auth-ac' as can break ssh on AL2, per V-255928."
    local Success="Fully updated the file settings, per V-255928."
    local Failure="Failed to set authconfig to use custom files and update it's settings, not in compliance with V-255928."

    if [ ! -f "/etc/pam.d/system-auth-ac" ]; then
        cp /etc/pam.d/system-auth /etc/pam.d/system-auth-ac
    fi

    if [ ! -f "/etc/pam.d/password-auth-ac" ]; then
        cp /etc/pam.d/password-auth /etc/pam.d/password-auth-ac
    fi

    if [ ! -f "/etc/pam.d/system-auth-local" ]; then
        echo "${Regex1}" >>/etc/pam.d/system-auth-local
        echo "${Regex2}" >>/etc/pam.d/system-auth-local
        echo "${Regex3}" >>/etc/pam.d/system-auth-local
        echo "${Regex4}" >>/etc/pam.d/system-auth-local
        echo "" >>/etc/pam.d/system-auth-local
        echo "${Regex5}" >>/etc/pam.d/system-auth-local
        echo "${Regex6}" >>/etc/pam.d/system-auth-local
        echo "" >>/etc/pam.d/system-auth-local
        echo "${Regex7}" >>/etc/pam.d/system-auth-local
        echo "${Regex8}" >>/etc/pam.d/system-auth-local
        echo "${Regex9}" >>/etc/pam.d/system-auth-local
        echo "${Regex10}" >>/etc/pam.d/system-auth-local
        echo "" >>/etc/pam.d/system-auth-local
        echo "${Regex11}" >>/etc/pam.d/system-auth-local
    else
        (grep -E -q "${Regex16}" /etc/pam.d/system-auth-local && sed -ri "${Regex17}.*$/${Regex2}/" /etc/pam.d/system-auth-local) || echo "${Regex2}" >>/etc/pam.d/system-auth-local
        (grep -E -q "${Regex18}" /etc/pam.d/system-auth-local && sed -ri "${Regex19}.*$/${Regex6}/" /etc/pam.d/system-auth-local) || echo "${Regex6}" >>/etc/pam.d/system-auth-local
        (grep -E -q "${Regex20}" /etc/pam.d/system-auth-local && sed -ri "${Regex21}.*$/${Regex9}/" /etc/pam.d/system-auth-local) || echo "${Regex9}" >>/etc/pam.d/system-auth-local
        (grep -E -q "${Regex22}" /etc/pam.d/system-auth-local && sed -ri "${Regex23}.*$/${Regex11}/" /etc/pam.d/system-auth-local) || echo "${Regex11}" >>/etc/pam.d/system-auth-local
    fi

    if [ ! -f "/etc/pam.d/password-auth-local" ]; then
        echo "${Regex1}" >>/etc/pam.d/password-auth-local
        echo "${Regex12}" >>/etc/pam.d/password-auth-local
        echo "${Regex3}" >>/etc/pam.d/password-auth-local
        echo "${Regex4}" >>/etc/pam.d/password-auth-local
        echo "" >>/etc/pam.d/password-auth-local
        echo "${Regex5}" >>/etc/pam.d/password-auth-local
        echo "${Regex13}" >>/etc/pam.d/password-auth-local
        echo "" >>/etc/pam.d/password-auth-local
        echo "${Regex7}" >>/etc/pam.d/password-auth-local
        echo "${Regex8}" >>/etc/pam.d/password-auth-local
        echo "${Regex14}" >>/etc/pam.d/password-auth-local
        echo "${Regex10}" >>/etc/pam.d/password-auth-local
        echo "" >>/etc/pam.d/password-auth-local
        echo "${Regex15}" >>/etc/pam.d/password-auth-local
    else
        (grep -E -q "${Regex24}" /etc/pam.d/password-auth-local && sed -ri "${Regex25}.*$/${Regex12}/" /etc/pam.d/password-auth-local) || echo "${Regex12}" >>/etc/pam.d/password-auth-local
        (grep -E -q "${Regex26}" /etc/pam.d/password-auth-local && sed -ri "${Regex27}.*$/${Regex13}/" /etc/pam.d/password-auth-local) || echo "${Regex13}" >>/etc/pam.d/password-auth-local
        (grep -E -q "${Regex28}" /etc/pam.d/password-auth-local && sed -ri "${Regex29}.*$/${Regex14}/" /etc/pam.d/password-auth-local) || echo "${Regex14}" >>/etc/pam.d/password-auth-local
        (grep -E -q "${Regex30}" /etc/pam.d/password-auth-local && sed -ri "${Regex31}.*$/${Regex15}/" /etc/pam.d/password-auth-local) || echo "${Regex15}" >>/etc/pam.d/password-auth-local
    fi

    ln -sf /etc/pam.d/system-auth-local /etc/pam.d/system-auth
    ln -sf /etc/pam.d/password-auth-local /etc/pam.d/password-auth

    echo
    (grep -E -q "${Regex32}" /etc/pam.d/system-auth && grep -E -q "${Regex33}" /etc/pam.d/system-auth && grep -E -q "${Regex34}" /etc/pam.d/system-auth && grep -E -q "${Regex35}" /etc/pam.d/system-auth) || {
        echo "${Failure}"
    }
    ( (grep -E -q "${Regex36}" /etc/pam.d/password-auth && grep -E -q "${Regex37}" /etc/pam.d/password-auth && grep -E -q "${Regex38}" /etc/pam.d/password-auth && grep -E -q "${Regex39}" /etc/pam.d/password-auth) && echo "${Success}") || {
        echo "${Failure}"
    }

    if [ "${OSType}" = "AL2" ]; then
        sed -ri "/${Regex6}/d" /etc/pam.d/system-auth-local
        sed -ri "/${Regex11}/d" /etc/pam.d/system-auth-local
        sed -ri "/${Regex13}/d" /etc/pam.d/password-auth-local
        sed -ri "/${Regex15}/d" /etc/pam.d/password-auth-local

        (grep -E -q "${Regex33}" /etc/pam.d/system-auth && grep -E -q "${Regex25}" /etc/pam.d/system-auth) && {
            echo "${Failure}"
        }
        echo
        ( (grep -E -q "${Regex38}" /etc/pam.d/password-auth && grep -E -q "${Regex39}" /etc/pam.d/password-auth) || echo "${ALSuccess}") || {
            echo "${Failure}"
        }
    fi
}

#Set SSH server to only use FIPS-validated key exchange algorithms, V-255925
function V255925() {
    local Regex1="^(\s*)#KexAlgorithms\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#KexAlgorithms\s+\S+(\s*#.*)?\s*$/\KexAlgorithms ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256/"
    local Regex3="^(\s*)KexAlgorithms\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)KexAlgorithms\s+\S+(\s*#.*)?\s*$/\KexAlgorithms ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256/"
    local Regex5="^(\s*)KexAlgorithms\s*ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256\s*$"
    local Success="Successfully set SSH server to only use FIPS-validated key exchange algorithms, per V-255925"
    local Failure="Failed to set SSH server to only use FIPS-validated key exchange algorithms, not compliant with V-255925"

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "KexAlgorithms ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Set OS to restrict access to kernel message bugger, V-255927
function V255927() {
    local Regex1="^(\s*)#kernel.dmesg_restrict\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#kernel.dmesg_restrict\s+\S+(\s*#.*)?\s*$/\kernel.dmesg_restrict = 1\2/"
    local Regex3="^(\s*)kernel.dmesg_restrict\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)kernel.dmesg_restrict\s+\S+(\s*#.*)?\s*$/\kernel.dmesg_restrict = 1\2/"
    local Regex5="^(\s*)kernel.dmesg_restrict\s*=\s*1?\s*$"
    local Success="Set OS to restrict access to kernel message bugger, per V-255927."
    local Failure="Failed to set OS to restrict access to kernel message bugger, not in compliance V-255927."

    echo
    ( (grep -E -q "${Regex1}" /etc/sysctl.conf && sed -ri "${Regex2}" /etc/sysctl.conf) || (grep -E -q "${Regex3}" /etc/sysctl.conf && sed -ri "${Regex4}" /etc/sysctl.conf)) || echo "kernel.dmesg_restrict = 1" >>/etc/sysctl.conf
    (grep -E -q "${Regex5}" /etc/sysctl.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Install mailx, V-256970
function V256970() {
    local Success="mailx is installed, per V-256970."
    local Failure="Failed to install mailx, not in compliance with V-256970."

    echo
    if yum -q list installed mailx &>/dev/null; then
        echo "${Success}"
    else
        yum install -q -y mailx
        ( (yum -q list installed mailx &>/dev/null) && echo "${Success}") || {
            echo "${Failure}"
        }
    fi
}

#Apply all CATIIs
function Medium() {
    echo
    echo "----------------------------------"
    echo " Applying all compatible CAT IIs"
    echo "----------------------------------"

    #Check if pam is installed for various settings, /etc/secuirty
    if yum -q list installed pam &>/dev/null; then
        V255928 #Need to be first due rest now modifying a file introduced with this STIG
        V204405
        V204406
        V204407
        V204408
        V204409
        V204410
        V204411
        V204412
        V204413
        V204414
        V204415
        V204422
        V204423
        V204427
    else
        echo
        echo "Pam is not installed skipping V-204405, V-204406, V-204407, V-204408, V-204409, V-204410, V-204411, V-204412, V-204413, \
V-204414, V-204415, V-204422, V-204423, V-204427, and V-255928."
    fi

    #Check if Shadow-utils is installed for various settings, /etc/login.defs, /etc/default/useradd
    if yum -q list installed shadow-utils &>/dev/null; then
        V204416
        V204418
        V204426
        V204431
        V204457
        V204466
    else
        echo
        echo "Shadow-utils is not installed skipping V-204416, V-204418, V-204426, V-204431, V-204457 and V-204466."
    fi

    #Check if libuser is installed, /etc/libuser.conf
    if yum -q list installed libuser &>/dev/null; then
        V204417
    else
        echo
        echo "Libuser is not installed skipping V-204417."
    fi

    #Check if openssh is installed, /etc/ssh
    if yum -q list installed openssh &>/dev/null; then
        V204435
        V204587
        V204589
        V204590
        V204591
        V204592
        V204593
        V204598
        V204599
        V204600
        V204602
        V204622
        V233307
        V255925

        if [ "${OSType}" = "AL2" ]; then
            V204578
            V204595
        fi
    else
        echo
        echo "Openssh is not installed skipping V-204435, V-204587, V-204589, V-204590, V-204591, V-204592, V-204593, V-204598, \
V-204599, V-204600, V-204602, V-204622, V-233307, and V-255925."
    fi

    #Check if systemd is installed, /usr/lib/systemd
    if yum -q list installed systemd &>/dev/null; then
        V204437
    else
        echo
        echo "systemd is not installed skipping V-204437."
    fi

    #Check if audit is installed, /etc/audit
    if yum -q list installed audit &>/dev/null; then
        V204503
    else
        echo
        echo "audit is not installed skipping V-204503, V-204516, V-204517, V-204521, V-204524, V-204527, V-204531, V-204536, V-204537, V-204538, \
V-204539, V-204540, V-204541, V-204542, V-204543, V-204544, V-204545, V-204546, V-204547, V-204548, V-204549, V-204550, V-204551, V-204552, \
V-204553, V-204554, V-204555, V-204556, V-204557, V-204558, V-204559, V-204560, V-204562, V-204563, V-204564, V-204565, V-204566, V-204567, \
V-204568 and V-204572."
    fi

    #Check if initscripts is installed, /etc/sysctl.conf
    if yum -q list installed initscripts &>/dev/null; then
        V204614
        V204615
        V204616
        V204617
        V255927
    else
        echo
        echo "initscripts is not installed skipping V-204584, V-204609, V-204610, V-204611, V-204612, V-204613, V-204614, V-204615, \
V-204616, V-204617, V-204625, V-204630, V-204602, and V255927."
    fi

    #Check if sudo is installed, /etc/sysctl.conf
    if yum -q list installed sudo &>/dev/null; then
        V251703
    else
        echo
        echo "sudo is not installed skipping V-237634, V-237635, and V-251703."
    fi

    #Check if kmod is installed, /etc/modprobe.d/
    if yum -q list installed kmod &>/dev/null; then
        V204449
        V204450
    else
        echo
        echo "kmod is not installed skipping V-204449 and V-204450."
    fi

    #Check if autofs is installed
    if yum -q list installed autofs &>/dev/null; then
        V204451
    else
        echo
        echo "autofs is not installed skipping V-204451."
    fi

    V204619
    V204631
    V204633
    V256970
}

#------------------
#CAT I STIGS\High
#------------------

#Set SSH to not allow authentication using empty passwords, V-204425.
function V204425() {
    local Regex1="^(\s*)#PermitEmptyPasswords\s+\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)#PermitEmptyPasswords\s+\S+(\s*#.*)?\s*$/\PermitEmptyPasswords no\2/"
    local Regex3="^(\s*)PermitEmptyPasswords\s+\S+(\s*#.*)?\s*$"
    local Regex4="s/^(\s*)PermitEmptyPasswords\s+\S+(\s*#.*)?\s*$/\PermitEmptyPasswords no\2/"
    local Regex5="^(\s*)PermitEmptyPasswords\s*no\s*$"
    local Success="Set SSH to not allow authentication using empty passwords, per V-204425."
    local Failure="Failed to set SSH to not allow authentication using empty passwords, not in compliance with V-204425."

    echo
    ( (grep -E -q "${Regex1}" /etc/ssh/sshd_config && sed -ri "${Regex2}" /etc/ssh/sshd_config) || (grep -E -q "${Regex3}" /etc/ssh/sshd_config && sed -ri "${Regex4}" /etc/ssh/sshd_config)) || echo "PermitEmptyPasswords no" >>/etc/ssh/sshd_config
    (grep -E -q "${Regex5}" /etc/ssh/sshd_config && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Remove rsh-server if installed, V-204442
function V204442() {
    local Success="rsh-server has been removed, per V-204442."
    local Failure="Failed to remove rsh-server, not in compliance with V-204442."

    echo

    if yum -q list installed rsh-server &>/dev/null; then
        yum remove -q -y rsh-server
        { (yum -q list installed rsh-server &>/dev/null) && {
            echo "${Failure}"
        }; } || echo "${Success}"
    else
        echo "${Success}"
    fi
}

#Remove ypserv if installed, V-204443
function V204443() {
    local Success="ypserv has been removed, per V-204443."
    local Failure="Failed to remove ypserv, not in compliance with V-204443."

    echo

    if yum -q list installed ypserv &>/dev/null; then
        yum remove -q -y ypserv
        { (yum -q list installed ypserv &>/dev/null) && {
            echo "${Failure}"
        }; } || echo "${Success}"
    else
        echo "${Success}"
    fi
}

#Verify that gpgcheck is Globally Activated, V-204447
function V204447() {
    local Regex1="^(\s*)gpgcheck\s*=\s*\S+(\s*#.*)?\s*$"
    local Regex2="s/^(\s*)gpgcheck\s*=\s*\S+(\s*#.*)?\s*$/gpgcheck=1\2/"
    local Regex3="^(\s*)gpgcheck\s*=\s*1\s*$"
    local Success="Yum is now set to require certificates for installations, per V-204447"
    local Failure="Yum was not properly set to use certificates for installations, not in compliance with V-204447"

    echo
    (grep -E -q "${Regex1}" /etc/yum.conf && sed -ri "${Regex2}" /etc/yum.conf) || echo "gpgcheck=1" >>/etc/yum.conf
    (grep -E -q "${Regex3}" /etc/yum.conf && echo "${Success}") || {
        echo "${Failure}"
    }
}

#Disable and mask  Ctrl-Alt-Delete, V-204455
function V204455() {
    local Success="Ctrl-Alt-Delete is disabled, per V-204455"
    local Failure="Ctrl-Alt-Delete hasn't been disabled, not in compliance with per V-204455"
    local Notinstalled="ctrl-alt-del.target was not installed on the system.  Disabled by default, per V-204455."

    echo

    if ! systemctl list-unit-files --full -all | grep -E -q '^ctrl-alt-del.target'; then
        echo "${Notinstalled}"
    else
        if systemctl status ctrl-alt-del.target | grep -E -q "active"; then
            systemctl stop ctrl-alt-del.target &>/dev/null
            systemctl disable ctrl-alt-del.target &>/dev/null
            systemctl mask ctrl-alt-del.target &>/dev/null
        fi

        if systemctl status ctrl-alt-del.target | grep -E -q "failed"; then
            (systemctl status ctrl-alt-del.target | grep -q "Loaded: masked" && echo "${Success}") || {
                echo "${Failure}"
            }
        else
            ( (systemctl status ctrl-alt-del.target | grep -q "Loaded: masked" && systemctl status ctrl-alt-del.target | grep -q "Active: inactive") && echo "${Success}") || {
                echo "${Failure}"
            }
        fi
    fi
}

#Remove telnet-server if installed, V-204502
function V204502() {
    local Success="telnet-server has been removed, per V-204502."
    local Failure="Failed to remove telnet-server, not in compliance with V-204502."

    echo

    if yum -q list installed telnet-server &>/dev/null; then
        yum remove -q -y telnet-server
        { (yum -q list installed telnet-server &>/dev/null) && {
            echo "${Failure}"
        }; } || echo "${Success}"
    else
        echo "${Success}"
    fi
}

#Remove vsftpd if installed, V-204620
function V204620() {
    local Success="vsftpd has been removed, per V-204620."
    local Failure="Failed to remove vsftpd, not in compliance with V-204620."

    echo

    if yum -q list installed vsftpd &>/dev/null; then
        yum remove -q -y vsftpd
        { (yum -q list installed vsftpd &>/dev/null) && {
            echo "${Failure}"
        }; } || echo "${Success}"
    else
        echo "${Success}"
    fi
}

#Remove tftp-server if installed, V-204621
function V204621() {
    local Success="tftp-server has been removed, per V-204621."
    local Failure="Failed to remove tftp-server, not in compliance with V-204621."

    echo

    if yum -q list installed tftp-server &>/dev/null; then
        yum remove -q -y tftp-server
        { (yum -q list installed tftp-server &>/dev/null) && {
            echo "${Failure}"
        }; } || echo "${Success}"
    else
        echo "${Success}"
    fi
}

function High() {
    echo
    echo "----------------------------------"
    echo "  Applying all compatible CAT Is"
    echo "----------------------------------"

    #Check if openssh is installed, /etc/ssh
    if yum -q list installed openssh &>/dev/null; then
        V204425
    else
        echo
        echo "Openssh is not installed skipping V-204425."
    fi

    #Check if system has been booted with systemd as init system
    if [ "${ISPid1}" = "1" ]; then
        V204455
    else
        echo
        echo "System has not been booted with systemd as init system, skipping V-204455."
    fi

    V204442
    V204443
    V204447
    V204502
    V204620
    V204621
}

#------------------
#Clean up
#------------------

function Cleanup() {
    echo
    (rm -rf "${StagingPath}" && echo "Staging directory has been cleaned.") || echo "Failed to clean up the staging directory."
}

#Setting variable for default input
Level=${1:-"High"}
StagingPath=${2:-"/var/tmp/STIG"}

#Check if system has been booted with systemd as init system
ISPid1=$(pidof systemd || echo "404")

#Get OS
OSFile=/etc/os-release

if [ -e ${OSFile} ]; then
    . $OSFile
    OSVersion="$ID${VERSION_ID:+.${VERSION_ID}}"
else
    echo "The file ${OSFile} does not exist. Failing build."
    exit 1
fi

if [ $(echo "${OSVersion}" | grep -E "^amzn\.2") ]; then
    OSType="AL2"
elif [ $(echo "${OSVersion}" | grep -E "^((centos|rhel)\.7)") ]; then
    OSType="RHEL7"
else
    echo "This document is designed to work with only Amazon Linux 2, Red Hat Enterprise Linux (RHEL) 7, and CentOS 7. This OS is unsupported. Exiting."
    exit 1
fi

#Setting script to run through all stigs if no input is detected.
if [ "${Level}" = "High" ]; then
    echo
    echo "------------------------------------------"
    echo " Applying all compatible CAT Is and lower"
    echo "------------------------------------------"
    Low
    Medium
    High
elif [ "${Level}" = "Medium" ]; then
    echo
    echo "-------------------------------------------"
    echo " Applying all compatible CAT IIs and lower"
    echo "-------------------------------------------"
    Low
    Medium
elif [ "${Level}" = "Low" ]; then
    echo
    echo "--------------------------------------------"
    echo " Applying all compatible CAT IIIs and lower"
    echo "--------------------------------------------"
    Low
else
    for Level in "$@"; do
        "${Level}"
    done
fi

Cleanup
sysctl --system &>/dev/null
exit 0