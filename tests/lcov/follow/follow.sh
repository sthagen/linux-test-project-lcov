#!/bin/bash
set +x

source ../../common.tst

rm -rf rundir *.info

clean_cover

if [[ 1 == $CLEAN_ONLY ]] ; then
    exit 0
fi


LCOV_OPTS="$PARALLEL $PROFILE"
# gcc/4.8.5 (and possibly other old versions) generate inconsistent line/function data
IFS='.' read -r -a VER <<< `${CC} -dumpversion`
if [ "${VER[0]}" -lt 5 ] ; then
    IGNORE="--ignore inconsistent"
fi


mkdir -p rundir
cd rundir

rm -Rf src src2

mkdir src
ln -s src src2

echo 'int a (int x) { return x + 1; }' > src/a.c
echo 'int b (int x) { return x + 2; }' > src/b.c

${CC} -c --coverage src/a.c -o src/a.o
${CC} -c --coverage src2/b.c -o src/b.o

$COVER $LCOV_TOOL -o out2.info --capture --initial --no-external -d src --follow --rc geninfo_follow_file_links=1
if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from lcov --initial --follow"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

COUNT2=`grep -c SF: out2.info`
if [ 2 != $COUNT2 ] ; then
    echo "Error:  expected COUNT==2, found $COUNT2"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

$COVER $GENINFO_TOOL -o out3.info --initial --no-external src --follow --rc geninfo_follow_file_links=1
if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from geninfo --initial --follow"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

diff out3.info out2.info
if [ 0 != $? ] ; then
    echo "Error:  expected identical geninfo output"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

$COVER $GENINFO_TOOL -o out4.info --initial --no-external src2 --follow
if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from lcov src2"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

diff out4.info out2.info
# should not be identical as the 'src2/b.c' path should be in 'out4.info'
if [ 0 == $? ] ; then
    echo "Error:  expected not identical geninfo output"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi
cat out4.info | sed -e s/src2/src/g > out5.info
diff out5.info out2.info
# should be identical now
if [ 0 != $? ] ; then
    echo "Error:  expected identical geninfo output after substitution"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

cd ..
$COVER $GENINFO_TOOL -o top.info --initial --no-external rundir --follow
if [ 0 != $? ] ; then
    echo "Error:  unexpected error code from lcov src2"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi
diff top.info rundir/out4.info
# should be identical now
if [ 0 != $? ] ; then
    echo "Error:  expected identical geninfo output after substitution"
    if [ $KEEP_GOING == 0 ] ; then
        exit 1
    fi
fi

echo "Tests passed"

if [ "x$COVER" != "x" ] && [ $LOCAL_COVERAGE == 1 ]; then
    cover
fi
