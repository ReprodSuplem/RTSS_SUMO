This is an instruction for reproducing the experiments described in our submission. 
A video demonstration of our simulation is available at https://youtu.be/f2FpVc17SBA.

===== Part A =====
What the experimental environments we need? ->
Operation system: Ubuntu 18.04
Ruby version: 2.5.1
GCC version: 7.3.0
SUMO version: 0.32

Install SUMO in Ubuntu: 
 $ sudo apt-get install sumo sumo-tools sumo-doc

Setup QMaxSAT solver with incremental approach
 $ cd ./source_code/sumoutil/QMaxSAT_ncc/code/
 $ make clean && make
 $ cp ./qmaxsatNcc_g3 ../../encodedProblem/qmaxsatNcc_g3

===== Part B =====
How to run experiments (described in Section 5)? ->
Firstly, 
 $ cd ./source_code/sumoutil/sample/001.Tsukuba
we can simulate an experiment for SBI allocation (existing method) 
 $ ./runSBI.sh
or, we can simulate an experiment for SAT-based allocation (proposed approach) 
 $ ./runSAT.sh
All output files are exported to the following directories: 
 ./source_code/sumoutil/expDir/genrdMaxInst/
 ./source_code/sumoutil/expDir/maxSATime/
 ./source_code/sumoutil/expDir/seqOpTime/
All log files are exported to the directory: ./source_code/sumoutil/sample/001.Tsukuba/,Log/

Do not forget to remove the generated files (including encode files, log files, answer files) 
before the next running of ./runSBI.sh or ./runSAT.sh
 $ ./reset.sh

The default parameter settings:
the number of taxis = 20
the demand occurrence frequency = 3600/100 (interval = 100)
...
We can change any test value (integer) in the following files:
./source_code/sumoutil/sample/001.Tsukuba/tsukuba.00.savSimConf.json (taxi's information/parameters)
./source_code/sumoutil/sample/001.Tsukuba/tsukuba.00.demandConf.json (demand's information/parameters)

===== Part C =====
How to simulate for the real-world data (mentioned in Appendix D)? ->
Firstly, 
 $ cd ./source_code/sumoutil/sample
we need to build the symbolic links 
 $ ln -s ../Savs ./Savs && ln -s ../Tools ./Tools && ln -s ../Traci ./Traci
Then, 
 $ cd ./2018.1005.Yokohama
we can simulate an experiment for SBI allocation (existing method) 
 $ ./runSBI.sh
or, we can simulate an experiment for SAT-based allocation (proposed approach) 
 $ ./runSAT.sh
All output files are exported to the following directories: 
 ./source_code/sumoutil/expDir/genrdMaxInst/
 ./source_code/sumoutil/expDir/maxSATime/
 ./source_code/sumoutil/expDir/seqOpTime/
All log files are exported to the directory: ./source_code/sumoutil/sample/2018.1005.Yokohama/,Log/

Do not forget to remove the generated files (including encode files, log files, answer files) 
before the next running of ./runSBI.sh or ./runSAT.sh
 $ ./reset.sh

The default parameter settings:
the date of the imported real-world data = 2018-12-01
...
We can change any test value (integer) in the following files:
./source_code/sumoutil/sample/2018.1005.Yokohama/yokohamaNedo.02.savSimConf.json (taxi's information/parameters)
./source_code/sumoutil/sample/2018.1005.Yokohama/yokohamaNedo.02.demandConf.json (demand's information/parameters)

===== Part D =====
A detected algorithm core with a sample initialization is given in directory
 ./source_code/sat-based_rtss_v1.1
