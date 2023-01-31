#!/bin/bash
########################################################################
#  (@)sql.sh
#
#  Copyright 2014 by Oracle Corporation,
#  500 Oracle Parkway, Redwood Shores, California, 94065, U.S.A.
#  All rights reserved.
#
#  This software is the confidential and proprietary information
#  of Oracle Corporation.
#
# NAME	sql
#
# DESC 	This script starts SQL CL.
#
# AUTHOR bamcgill
#
# MODIFIED
#   bamcgill    21/03/2014  Created
#   bamcgill    18/07/2014  Simplified classpaths and args
#   bamcgill    11/12/2014  Renamed script and contents
#   bamcgill    16/01/2015  Renamed script and contents
#   bamcgill    05/02/2015  Added STD_ARGS for headless and other args
#   cdivilly    12/02/2015  Locate home folder via symlinks
#   bamcgill    10/06/2015  Quote jarfiles for dirs with spaces
#   bamcgill    02/10/2015  Adding specific JAVA_HOME for ADE dev users
#   totierne    02/10/2015  use -cp instead of JARFILE to add ojdbc6
#   bamcgill    14/10/2015  switch Cygwin settings so Cygwin Term will work
#   totierne    16/10/2015  add classpath to allow times ten jars
#   bamcgill    17/10/2015  Cleaning up bootstrap to call single java
#                           implementation with pruned args.
#   totierne    12/05/2016  added $OH/lib to $LD_LIBRARY_PATH when $OH
#   bamcgill    12/05/2016  adding -cleanup to args
#   bamcgill    29/06/2016  Added more checks around JAVA_HOME settings
#   bamcgill    04/07/2016  Using the ADE RDBMS JDK if it exists.
#   jmcginni    23/08/2016  Grab Proxy info on Mac, KDE, Gnome
#   bamcgill    04/11/2016  Added all jars to classpath and pointed cobertura
#                           ser file for running.
#   bamcgill    17/11/2016  Added $OH/jdk as java location if JAVA_HOME not set
#   bamcgill    16/10/2017  Enumerated the libraries for sqlcl to avoid unwanted
#                           class loads
#   bamcgill    11/03/2017  Added classpaths for jars in different locations
#                           embedded in Oracle SQLDeveloper
#   bamcgill    11/06/2017  Added classpaths for drivers and exts.
#   bamcgill    10/05/2019  Hardened support for MINGW console on windows
#   bamcgill    21/05/2019  Adding silence for nashorn warning after jdk11
#   bamcgill    19/06/2019  Adding slf4j as its used with lb support and
#                           the new ssh implementation:wq
#   bamcgill    14/11/2019  Removing funny comments from file.
#   skutz       29/01/2020  Added utility function to get java version and 
#			    used in in ADE setup function						
#   bamcgill    12/03/2020  Adding LANG and LC_ALL variables for forcing 
#                           sqlcl into a particular language
#   bamcgill    03/06/2020  Changing the DEBUG Flag to be explicitly called 
#                           SQLCL_DEBUG which will allow debugging of sqlcl java.
#   bamcgill    23/07/2020  In docker alpine images, LANG defaults to C or posix
#                           in this case we default to en_US.UTF8
#   bamcgill    27/01/2021  Adding jars and flags for Graal.js support.  This is
#                           important as jdk15 removes nashorn which was deprecated
#                           in JDK11
#   bamcgill    28/03/2022  Adding Java Check for minimum of 11
#   admuro      06/10/2022  Validate if graalvm is installed (OCI) and set the path
#                           as the JAVA_HOME
#   josmende    01/11/2022  Adding eclipse parsson to the classpath
########################################################################

AddVMOption()
{
  APP_VM_OPTS[${#APP_VM_OPTS[*]}]="$*"
}

# Utility function to get java version
function jdk_version() {
  local result
  local java_cmd
  if [[ -n $(type -p java) ]]
  then
    java_cmd=java
  elif [[ (-n "$JAVA_HOME") && (-x "$JAVA_HOME/bin/java") ]]
  then
    java_cmd="$JAVA_HOME/bin/java"
  fi
  local IFS=$'\n'
  # remove \r for Cygwin
  local lines=$("$java_cmd" -Xms32M -Xmx32M -version 2>&1 | tr '\r' '\n')
  if [[ -z $java_cmd ]]
  then
    result=no_java
  else
    for line in $lines; do
      if [[ (-z $result) && ($line = *"version \""*) ]]
      then
        local ver=$(echo $line | sed -e 's/.*version "\(.*\)"\(.*\)/\1/; 1q')
        # on macOS, sed doesn't support '?'
        if [[ $ver = "1."* ]]
        then
          result=$(echo $ver | sed -e 's/1\.\([0-9]*\)\(.*\)/\1/; 1q')
        else
          result=$(echo $ver | sed -e 's/\([0-9]*\)\(.*\)/\1/; 1q')
        fi
      fi
    done
  fi
  echo "$result"
}

#
# if we are in ADE environement, check for JAVA_HOME
#
function checkADE {
    #
	# Resolve java path for development builds
	#
    # First thing is to see if we are in a VIEW
    if [ "m$ADE_VIEW_ROOT" != "m" ]; then
        #  Do we have and ORACLE_HOME set in the view?
        if  [  "m$ORACLE_HOME" != "m" ]; then
            # is there a jre in teh ORACLE_HOME?
            if  [ -d "$ORACLE_HOME/jdk/jre" ]; then
                if [[ "$(jdk_version)" -gt "8" ]]; then
                    JAVA_HOME="$ORACLE_HOME/jdk/jre"
                    PATH="$JAVA_HOME/bin:$PATH"
                else
                    unset ORACLE_HOME
                    echo "ADE: Not using ORACLE_HOME java bad version."
                fi
            fi
            export SQLPLUS_CLASSIC=true
        fi
    fi
}

#
# if we are in OCI environement, check for JAVA_HOME
#
function checkOCI {
  if [ -f /usr/lib64/graalvm/graalvm22-ee-java17/bin/java ] ; then 
    JAVA_HOME=/usr/lib64/graalvm/graalvm22-ee-java17
    PATH="$JAVA_HOME/bin:$PATH"
  fi
}

#
# set up the main arguments for java.
#
function setupArgs {
	#
	# Standard JVM options which are always used
	#
	AddVMOption -Djava.awt.headless=true
	if [[ $JAVA_INUSE -eq 11 ]] || [[ $JAVA_INUSE -gt 11 ]];
	then	
          AddVMOption -Dnashorn.args="--no-deprecation-warning"
	fi
	AddVMOption -Dapple.awt.UIElement=true
	AddVMOption -Xms64M
	AddVMOption -Xmx2G
    AddVMOption -Xss100m
	if test "m$(uname -s)" = "mHP-UX"
	then
	   AddVMOption -d64
	fi
	# ignore cover up windows registry warning which errors on java 8
	AddVMOption -XX:+IgnoreUnrecognizedVMOptions
	# cover up windows read registry warning
        AddVMOption --add-opens=java.prefs/java.util.prefs=ALL-UNNAMED
  # enable graal scripts
  AddVMOption -Dpolyglot.js.nashorn-compat=true
}

#
# Set SQLHOME to be canonical paths
#
function setupSQLHome {
	#
	# resolve the folder where this script is located, traversing any symlinks
	#
	PRG="$0"
	# loop while $PRG is a symlink
	while [ -h "$PRG" ] ; do
	  # figure out target of the symlink
	  ls=`ls -ld "$PRG"`
	  link=`expr "$ls" : '.*-> \(.*\)$'`
	  # traverse to the target of the symlink
	  if expr "$link" : '/.*' > /dev/null; then
	  PRG="$link"
	  else
	  PRG=`dirname "$PRG"`"/$link"
	  fi
	done

	#
	# SQLHOME is where we live.  Lets get an exact address.
	# sql script is in ${SQL_HOME}/bin so lets check above and get the
	# canonical path for that
	#
	SQL_HOME=`dirname "$PRG"`/..
	export SQL_HOME=`cd "${SQL_HOME}" > /dev/null && pwd`
}

function setupCPLIST {
CPLIST="$SQL_HOME/lib/jansi.jar"
CPLIST="$SQL_HOME/lib/guava-with-lf.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/antlr-runtime.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jline3.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/orai18n-mapping.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jdbcrest.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/commons-codec.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/sshd-core.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/sshd-common.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/sshd-contrib.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/orai18n-servlet.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-data.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-datapump.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-cpat.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-common.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-http.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-net.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/dbtools-sqlcl.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/ojdbc11.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/orai18n-utility.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/httpclient5.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/orajsoda.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/httpcore5.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/osdt_cert.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/osdt_core.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jackson-annotations.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/oraclepki.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/ST4.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jackson-core.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/xdb6.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/xdb.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jackson-jr-objects.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jackson-jr-stree.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/orai18n-collation.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/xmlparserv2_sans_jaxp_services.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/orai18n.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/commons-logging.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/xmlparserv2.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/jakarta.json-api.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/parsson.jar:$CPLIST"

CPLIST="$SQL_HOME/lib/slf4j-jdk14.jar:$CPLIST"
CPLIST="$SQL_HOME/lib/slf4j-api.jar:$CPLIST"

#SQLDeveloper file locations (when embedded)
CPLIST="$SQL_HOME/../modules/oracle.xdk/xmlparserv2.jar:$CPLIST"
CPLIST="$SQL_HOME/../jlib/orai18n.jar:$CPLIST"
CPLIST="$SQL_HOME/../jlib/orai18n-mapping.jar:$CPLIST"
CPLIST="$SQL_HOME/../jlib/orai18n-utility.jar:$CPLIST"
CPLIST="$SQL_HOME/../jdbc/lib/ojdbc11.jar:$CPLIST"
CPLIST="$SQL_HOME/../rdbms/jlib/xdb6.jar:$CPLIST"
CPLIST="$SQL_HOME/../rdbms/jlib/xdb.jar:$CPLIST"

CPLIST="$SQL_HOME/lib/ext/*:$CPLIST"
CPLIST="$SQL_HOME/lib/drivers/*:$CPLIST"
CPLIST="$SQL_HOME/lib/jansi.jar:$CPLIST"

if [ ! -z ${GRAALVM} ] &&  [ -d $GRAALVM ];
then
  CPLIST="$GRAALVM/jre/languages/js/graaljs.jar:$CPLIST"
  CPLIST="$GRAALVM/jre/tools/regex/tregex.jar:$CPLIST"
  CPLIST="$GRAALVM/jre/lib/boot/graal-sdk.jar:$CPLIST"
  CPLIST="$GRAALVM/jre/lib/truffle/truffle-api.jar:$CPLIST"
  CPLIST="${GRAALVM}/jre/lib/boot/graaljs-scriptengine.jar:${CPLIST}"
  CPLIST="${GRAALVM}/jre/languages/js/icu4j.jar:${CPLIST}"
fi
}
#
# Setup classpath depending on where we are
#
function setupClasspath {
    # Bootstrap classpath
       setupCPLIST
	#
	# If we are in an ORACLE_HOME, then we want to try to use the jdbc
	# drivers in there.
	# Here we are frontloading the Oracle JDBC jars. We are not version
	# checking at this stage.
	#
	if test  "m$ORACLE_HOME" = "m"
	then
	  CPLIST="$SQL_HOME/lib/dbtools-sqlcl.jar:$CPLIST:$CLASSPATH"
	else
	  # where ORACLE_HOME points to ordinary ORACLE_HOME or
	  # INSTANT_CLIENT (or use shipped with sqlcl ojdbc8.jar)
	  CPLIST="$ORACLE_HOME/jdbc/lib/ojdbc11.jar:$ORACLE_HOME/jdbc/lib/ojdbc8.jar:$ORACLE_HOME/ojdbc11.jar:$ORACLE_HOME/ojdbc8.jar:$ORACLE_HOME/jdbc/lib/ojdbc7.jar:$ORACLE_HOME/ojdbc7.jar:$ORACLE_HOME/jdbc/lib/ojdbc6.jar:$ORACLE_HOME/ojdbc6.jar:$CPLIST:$CLASSPATH"
	   export LD_LIBRARY_PATH="$ORACLE_HOME/lib:$ORACLE_HOME:$LD_LIBRARY_PATH"
	fi

	if test "m$(uname -s)" = "mAIX"
	then
	   export LIBPATH=$LD_LIBRARY_PATH:$LIBPATH
	fi

	#
	# Lets look for jars in the extensions
	# directory under lib.  These will be loaded
	# at startup as well.
	#
	if  [ -f "$SQL_HOME/cobertura.ser" ]
	then
	#Setup cobertura classpath
		COBERTURA="$SQL_HOME/lib/cobertura-2.1.1.jar"
		INSTRUMENTED_CLASSES="$SQL_HOME/lib/dbtools-common.jar:$SQL_HOME/lib/dbtools-sqlcl.jar"
		CPLIST="$COBERTURA:$INSTRUMENTED_CLASSES:$SQL_HOME/lib/*:$CLASSPATH"
		AddVMOption -Dnet.sourceforge.cobertura.datafile="$SQL_HOME/cobertura.ser"
	fi
}
#
# Do you use cygwin?  Lets see and make the classpath right
#
function checkCygwin {

#
# Ok, now we have a classpath, lets make sure it works with Cygwin too.
#
	#
	# Check for Cygwin
	#
	cygwin=false
	case `uname` in
		MINGW64*) cygwin=true;;
		 CYGWIN*) cygwin=true;;
	esac

	#
	# If its Cygwin, then convert the classpath to posix style.
	# Convert the terminal to something that the Cygwin terminal
	# will understand and force jline to use a unix terminal as
	# cygwin reports TTY style badly
	if $cygwin; then
	 CPLIST=$(cygpath -pw "$CPLIST")
	 stty -icanon min 1 -echo > /dev/null 2>&1
	 stty icanon echo > /dev/null 2>&1
	 CYGWIN=-Djline.terminal=jline.UnixTerminal
	fi
}

#
# Check if JAVA_HOME is set and if so, make sure we run the java there.
#
function checkJavaLocation {

#Test for JAVA_HOME settings.  If it is set, we want to use it over and above what /usr/bin/java says
JAVA=java
 if  [  "m$JAVA_HOME" != "m" ]; then
   if  [ -d "$JAVA_HOME" ];
   then
 	JAVA="$JAVA_HOME/bin/java";
 	fi
  fi
  if [  "m$ORACLE_HOME" != "m" ]; then
    #if there is a jdk in the Oracle home and JAVA_HOME is not set
     if  [ -d "$ORACLE_HOME/jdk" ] && [  "m$JAVA_HOME" == "m" ];
     then
       JAVA_HOME="$ORACLE_HOME/jdk";
       JAVA="$JAVA_HOME/bin/java"
     fi
   fi
   # If you have downloaded a jre, dropping it into sqlcl as jre will make it first in line
  if [ -d "$SQL_HOME/jre/" ]; then
	 JAVA_HOME="$SQL_HOME/jre/"
	 PATH="$JAVA_HOME/bin:$PATH"
         JAVA="$JAVA_HOME/bin/java"
  fi
  # If you have downloaded sqldeveloper, with sqlcl in it, embedded jre will be here
  if [ -d "$SQL_HOME/../jdk/jre/" ]; then
	 JAVA_HOME="$SQL_HOME/../jdk/jre/"
	 PATH="$JAVA_HOME/bin:$PATH"
         JAVA="$JAVA_HOME/bin/java"
  fi
  JAVA_INUSE=`$JAVA -version  2>&1 >/dev/null | grep  version| awk -F\" {'print $2'} | awk -F. {'print $1'}`
}

#
# Check for proxies
#

# The following HTTP proxy-related code taken from NetBeans nbexec script.
DetectSystemHttpProxySetting()
{

    unset http_proxy_tmp

    if [ `uname` = Darwin ] ; then
	detect_macosx_proxy
    else
	if [ "$KDE_FULL_SESSION" = "true" ] ; then
            detect_kde_proxy
	else
            if [ ! -z "$GNOME_DESKTOP_SESSION_ID" ] ; then
        	detect_gnome_proxy
            fi
	fi
    fi

    # fall back to the environment-defined http_proxy if nothing found so far
    if [ -z "$http_proxy_tmp" ]; then
	http_proxy_tmp=$http_proxy
    fi

    if [ ! -z "$http_proxy_tmp" ] ; then
	    AddVMOption -Ddbtools.system_http_proxy=$http_proxy_tmp
	    AddVMOption -Ddbtools.system_http_non_proxy_hosts=$http_non_proxy_hosts
    fi

    if [ ! -z "$socks_proxy_tmp" ] ; then
	    AddVMOption -Ddbtools.system_socks_proxy=$socks_proxy_tmp
	    AddVMOption -Doracle.jdbc.javaNetNio=false
    fi

}

#
# figure out why locale settings are done in the terminal.
# were supporting these formats
#    en
#    en_US
#    en_US.UTF-8
#    en_US.UTF-8@modifier
#    en.UTF-8
#    en.UTF-8@modifier
#    en@modifier
#    en_US@modifier
# 
function checkLanguageSettings () {
# Use LC_MESSAGE if set; otherwise, use LANG
  local TMPLANG=${LC_MESSAGE:-${LANG}}
  # echo ${TMPLANG}
    if [ ! -z "${TMPLANG}" ] ; then
        local IFS=@
        set -- $TMPLANG
        if [ ! -z  $2 ]; then
         local SQLCL_MODIFIER=$2
        fi
        local IFS=.
        set -- $1
        if [ ! -z $2 ]; then
         local SQLCL_ENCODING=$2
        fi
        local IFS=_
        set -- $1
        if [ ! -z $2 ]; then
         local SQLCL_TERRITORY=$2
        fi
        local SQLCL_LANG=$1
        if [ "${SQLCL_LANG}" = "C" -o "${SQLCL_LANG}" = "POSIX" ]
        then 
           # for straight C/POSIX, drop in ascii with us english
            SQLCL_LANG="en"
            SQLCL_TERRITORY="US"
           if [ ! -z ${SQLCL_ENCODING} ]
           then
             SQLCL_ENCODING=UTF8
           fi
        fi
        if [ ! -z "${SQLCL_LANG}" ] ; then
           AddVMOption -Duser.language=${SQLCL_LANG}
        fi

        if [ ! -z "${SQLCL_TERRITORY}" ] ; then
          AddVMOption -Duser.region=${SQLCL_TERRITORY}
        fi

        if [ ! -z "${SQLCL_ENCODING}" ] ; then
           AddVMOption -Dfile.encoding=${SQLCL_ENCODING}
        fi
   fi
}

detect_system_proxy () {
    if [ ! -z "$http_proxy" ]; then
        http_proxy_tmp=$http_proxy
    fi
    return 0
}

detect_gnome_proxy () {
    gconftool=/usr/bin/gconftool-2
    if [ -x  $gconftool ] ; then
        proxy_mode=`$gconftool --get /system/proxy/mode 2>/dev/null`
        if [ "$proxy_mode" = "manual" ] ; then
            http_proxy_host=`$gconftool --get /system/http_proxy/host 2>/dev/null`
            http_proxy_port=`$gconftool --get /system/http_proxy/port 2>/dev/null`
            http_proxy_tmp=$http_proxy_host:$http_proxy_port
            http_non_proxy_hosts=`$gconftool --get /system/http_proxy/ignore_hosts 2>/dev/null`
            if [ $? ] ; then
                http_non_proxy_hosts=`echo $http_non_proxy_hosts | /bin/sed 's/\]//'`
            fi
            socks_proxy_host=`$gconftool --get /system/proxy/socks_host 2>/dev/null`
            socks_proxy_port=`$gconftool --get /system/proxy/socks_port 2>/dev/null`
            socks_proxy_tmp=$socks_proxy_host:$socks_proxy_port

            return 0
        else
            if [ "$proxy_mode" = "none" ] ; then
                detect_system_proxy
                if [ -z "$http_proxy_tmp" ]; then
                    http_proxy_tmp="DIRECT"
                fi
                return 0
            else
                if [ "$proxy_mode" = "auto" ] ; then
                    detect_system_proxy
                    pac_file=`$gconftool --get /system/proxy/autoconfig_url 2>/dev/null`
                    if [ ! -z "$pac_file" ]; then
                        http_proxy_tmp="PAC "$pac_file
                    fi
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

detect_kde_proxy () {
    kioslaverc="${HOME}/.kde/share/config/kioslaverc"
    if [ -f $kioslaverc ] ; then
        if /bin/grep 'ProxyType=1' "$kioslaverc" >/dev/null 2>&1; then
            http_proxy_tmp=`/bin/grep 'httpProxy=http://' "$kioslaverc"`
            if [ $? ] ; then
                http_proxy_tmp=`echo $http_proxy_tmp | /bin/sed 's/httpProxy=http:\/\///'`
                return 0
            fi
            http_non_proxy_hosts=`/bin/grep 'NoProxyFor=' "$kioslaverc"`
            if [ $? ] ; then
                http_non_proxy_hosts=`echo $http_non_proxy_hosts | /bin/sed 's/NoProxyFor=//'`
            fi
        else
            if /bin/grep 'ProxyType=0' "$kioslaverc" >/dev/null 2>&1; then
                detect_system_proxy
                if [ -z "$http_proxy_tmp" ]; then
                    http_proxy_tmp="DIRECT"
                fi
                return 0
            else
                if /bin/grep 'ProxyType=2' "$kioslaverc" >/dev/null 2>&1; then
                    pac_file=`grep "Proxy Config Script=" $kioslaverc  | cut -f 2 -d =`
                    http_proxy_tmp="PAC "$pac_file
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

detect_macosx_proxy () {
    if [ ! -x /usr/sbin/scutil ] ; then
	return 1
    fi

    scutil_out=/tmp/nb-proxy-detection.$$
    cat <<EOF | /usr/sbin/scutil > ${scutil_out}
open
show State:/Network/Global/Proxies
close
EOF

    if /usr/bin/grep "ProxyAuto.*: *1" ${scutil_out} >/dev/null 2>&1; then
        if  /usr/bin/grep "ProxyAutoConfigEnable.*: *1" ${scutil_out} >/dev/null 2>&1; then
            http_proxy_tmp="PAC `/usr/bin/grep ProxyAutoConfigURLString ${scutil_out} | /usr/bin/awk 'END{print $3}'`"
            rm ${scutil_out}
            return 0
        fi

        rm ${scutil_out}
        return 1
    fi

    if /usr/bin/grep "HTTPEnable *: *1" ${scutil_out} >/dev/null 2>&1; then
	http_proxy_host=`/usr/bin/grep HTTPProxy ${scutil_out} | /usr/bin/awk 'END{print $3}'`
	http_proxy_port=`/usr/bin/grep HTTPPort ${scutil_out} | /usr/bin/awk 'END{print $3} '`
        http_proxy_tmp=$http_proxy_host:$http_proxy_port
        rm ${scutil_out}
        return 0
    fi

    http_proxy_tmp="DIRECT"
    rm ${scutil_out}
    return 0
}

#
# if we have a debug flag, we want to remove it, but also tell java
# to switch on debugging. Hence we'll need a new array to pass to java
#
function processArgs {
 id=0;
 ISDEBUG=0;
 for var
 do
    if [ $var != '-debug' ]
    then
      ARGS[id]=$var;
      let id++;
    else
      ISDEBUG=1;
    fi
 done
 if [ $ISDEBUG == 1 ]
 then
    SQLCL_DEBUG="-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=8000"
 else
    SQLCL_DEBUG=""
 fi
}

#
# Run the tool.
#
function run {
 if  [  "m$SQLCL_DEBUG" != "m" ]; then
   echo "JAVA=$JAVA"
   echo "JAVA_OPTS=${APP_VM_OPTS[@]}"
   echo "DEBUG=$DEBUG"
   echo "CPLIST=$CPLIST"
   echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
   echo "$JAVA  $CUSTOM_JDBC $CYGWIN "${APP_VM_OPTS[@]}" -client $SQLCL_DEBUG -cp "$CPLIST" oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli "

 fi
"${JAVA}"  ${CUSTOM_JDBC} ${CYGWIN} "${APP_VM_OPTS[@]}" -client ${SQLCL_DEBUG} -cp "${CPLIST}" oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli "$@"
}

#
# This is where we start SQLcl properly. We're going to process the arguments
# sent in, build our classpath, build our JVM options, prepare the terminal
# and kick off the main.
#
function bootStrap {
	echo "$@" | grep '\-debug' > /dev/null 2>&1
	if test "m$?" != "m0"
	then
		#if it is not debug we can pass the arguments straight through
		#runNormalArgs
 		run "$@"
	   exit $?
	else
		# Process the arguments and see if we have are in debug mode
		processArgs "$@"
		#
		# if you want to see what is getting passed, uncomment the next line
		#echo "after process args ${ARGS[@]}"
		#runModifiedArgs
		run ${ARGS[*]}
	fi
}

function setupTmpFiles {
 echo PID=$$
 TMPFILE=passwd.$$
 trap "rm -f $TMPFILE" 0 1 2 3 15
}

#setupTmpFiles
checkADE
checkOCI
setupSQLHome
setupClasspath
checkCygwin
checkJavaLocation
checkLanguageSettings
setupArgs
DetectSystemHttpProxySetting
if [[ "$(jdk_version)" -ge "11" ]]; then
bootStrap "$@"
else
        echo
        echo "Error: SQLcl requires Java 11 and above to run."
        echo "       Found Java version $(jdk_version)."
        echo "       Please set JAVA_HOME to appropriate version."
        echo
        exit 1
fi

