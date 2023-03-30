#!/bin/bash
set +x

CLEAN_ONLY=0
COVER=

PARALLEL='--parallel 0'
PROFILE="--profile"
COVER_DB='cover_db'
LOCAL_COVERAGE=1
KEEP_GOING=0
while [ $# -gt 0 ] ; do

    OPT=$1
    shift
    case $OPT in

        --clean | clean )
            CLEAN_ONLY=1
            ;;

        -v | --verbose | verbose )
            set -x
            ;;

        --keep-going )
            KEEP_GOING=1
            ;;

        --coverage )
            #COVER="perl -MDevel::Cover "
            if [[ "$1"x != 'x' &&  $1 != "-"* ]] ; then
               COVER_DB=$1
               LOCAL_COVERAGE=0
               shift
            fi
            COVER="perl -MDevel::Cover=-db,$COVER_DB,-coverage,statement,branch,condition,subroutine "
            ;;

        --home | -home )
            LCOV_HOME=$1
            shift
            if [ ! -f $LCOV_HOME/bin/lcov ] ; then
                echo "LCOV_HOME '$LCOV_HOME' does not exist"
                exit 1
            fi
            ;;

        --no-parallel )
            PARALLEL=''
            ;;

        --no-profile )
            PROFILE=''
            ;;

        * )
            echo "Error: unexpected option '$OPT'"
            exit 1
            ;;
    esac
done

if [[ "x" == ${LCOV_HOME}x ]] ; then
       if [ -f ../../../bin/lcov ] ; then
           LCOV_HOME=../../..
       else
           LCOV_HOME=../../../../releng/coverage/lcov
       fi
fi
LCOV_HOME=`(cd ${LCOV_HOME} ; pwd)`

if [[ ! ( -d $LCOV_HOME/bin && -d $LCOV_HOME/lib && -x $LCOV_HOME/bin/genhtml && -f $LCOV_HOME/lib/lcovutil.pm ) ]] ; then
    echo "LCOV_HOME '$LCOV_HOME' seems not to be invalid"
    exit 1
fi

export PATH=${LCOV_HOME}/bin:${LCOV_HOME}/share:${PATH}
export MANPATH=${MANPATH}:${LCOV_HOME}/man

ROOT=`pwd`
PARENT=`(cd .. ; pwd)`

LCOV_OPTS="--rc lcov_branch_coverage=1 $PARALLEL $PROFILE"

rm -rf *.gcda *.gcno a.out *.info* *.txt* *.json dumper* testRC *.gcov *.gcov.*

if [ "x$COVER" != 'x' ] && [ 0 != $LOCAL_COVERAGE ] ; then
    cover -delete
fi

if [[ 1 == $CLEAN_ONLY ]] ; then
    exit 0
fi

g++ -std=c++1y --coverage exception.cpp
if [ 0 != $? ] ; then
    echo "Error:  unexpected error from gcc"
    exit 1
fi
$COVER $LCOV_HOME/bin/lcov $LCOV_OPTS --capture --initial --directory . -o initial.info
if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from lcov --initial"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

./a.out
if [ 0 != $? ] ; then
    echo "Error:  unexpected error return from a.out"
    exit 1
fi

$COVER $LCOV_HOME/bin/lcov $LCOV_OPTS --capture --directory . -o all.info --include '*/exception.cpp' --no-markers

if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from lcov extract"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

$COVER $LCOV_HOME/bin/lcov $LCOV_OPTS --list all.info

if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from lcov --list"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

# how many branches reported?
BRANCHES=`grep -c BRDA: all.info`
EXCEPTIONS=`grep -c ',e' all.info`

if [ $EXCEPTIONS != '0' ] ; then

    $COVER $LCOV_HOME/bin/lcov $LCOV_OPTS --capture --directory . -o filter.info --include '*/exception.cpp'

    if [ 0 != $? ] ; then
        echo "Error:  unexpected error code from lcov extract filter"
        if [ $KEEP_GOING == 0 ] ; then
            exit 1
        fi
    fi
    FILTER_BRANCHES=`grep -c BRDA: filter.info`
    FILTER_EXCEPTIONS=`grep -c ',e' filter.info`
    if [ $FILTER_BRANCHES == $BRANCHES ] ; then
        echo "Error:  did not filter exception branches: $BRANCHES -> $FILTER_BRANCHES"
        exit 1
    fi
    let DIFF=$BRANCHES-$FILTER_BRANCHES
    let DIFF2=$EXCEPTIONS-$FILTER_EXCEPTIONS
    if [ $DIFF != $DIFF2 ] ; then
        echo "Error: we seem to have filtered non-exception branches: $DIFF -> $DIFF2"
        exit 1
    fi
    
else
    echo "no exceptions identified - so nothing to do"
fi

echo "Tests passed"

if [ "x$COVER" != "x" ] && [ $LOCAL_COVERAGE == 1 ]; then
    cover
fi
