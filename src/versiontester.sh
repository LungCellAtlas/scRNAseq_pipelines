#!/bin/bash
# takes as input two version numbers and a sign < "=", ">", "<"> and 
# returns whether relation holds (true) or not (false)
# use e.g. like this:
# if ./versiontester.sh $conda_version $min_version_new '>'; then
#        conda_type="new"
# fi
v1=$1
v2=$2
comp_sign=$3
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

testvercomp () {
    vercomp $1 $2
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $3 ]]
    then
        # echo "FAIL: Expected '$3', Actual '$op', Arg1 '$1', Arg2 '$2'"
	# 1 means false
	return 1
    else
        # echo "Pass: '$1 $op $2'"
	return 0 # 0 means true
    fi
}
# now run actual test based on input arguments
testvercomp $v1 $v2 $comp_sign

# # Run tests
# # argument table format:
# # testarg1   testarg2     expected_relationship
# echo "The following tests should pass"
# while read -r test
# do
#     testvercomp $test
# done << EOF
# 1            1            =
# 2.1          2.2          <
# 3.0.4.10     3.0.4.2      >
# 4.08         4.08.01      <
# 3.2.1.9.8144 3.2          >
# 3.2          3.2.1.9.8144 <
# 1.2          2.1          <
# 2.1          1.2          >
# 5.6.7        5.6.7        =
# 1.01.1       1.1.1        =
# 1.1.1        1.01.1       =
# 1            1.0          =
# 1.0          1            =
# 1.0.2.0      1.0.2        =
# 1..0         1.0          =
# 1.0          1..0         =
# EOF
# 
# echo "The following test should fail (test the tester)"
# testvercomp 1 1 '>'
