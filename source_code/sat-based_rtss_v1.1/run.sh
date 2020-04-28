#!/bin/bash

rm -f ./rtss.wcnf
rm -f ./externality.txt
rm -f ./answer.txt
rm -f ./log.txt

python ./pySatFoRtss.py

./qmaxsatRtss -cpu-lim=10 -card=mrwto -pmodel=0 -incr=1 ./rtss.wcnf ./externality.txt ./answer.txt >> ./log.txt

#./qmaxsatRtss -cpu-lim=10 -card=mrwto -pmodel=0 -incr=1 ./rtss.wcnf ./externality.txt ./answer.txt

