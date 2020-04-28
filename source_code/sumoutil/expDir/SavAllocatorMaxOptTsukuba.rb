#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = Sequentially Optimal Insertion Allocation
## Author:: Anonymous3
## Version:: 0.0 2018/02/14 Anonymous3
##
## === History
## * [2018/02/14]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'pp' ;

require 'SavAllocator.rb' ;
#require 'SavAllocatMaxSATencoding.rb' ;
require 'SavAllocatMaxSATencodingNcc.rb' ;
#require 'SavAllocatMaxSATencodingNcc_1Demd-nPasg.rb' ;

#--======================================================================
#++
## Sav module
module Sav
  
  #--============================================================
  #++
  ## class for Allocator of SavDemand using sequentially optimal insertion
  class SavAllocatorSeqOpt < SavAllocator
    
    ## register this class as sub-class of SavAllocator.
    SavAllocator.registerSubClass("seqOpt", self) ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :foo => :bar,
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## foo
    attr_accessor :foo ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      super() ;
    end
    
    #------------------------------------------
    #++
    ## allocate SAVs to the list of demands randomly.
    ## _demandList_:: list of SavDemand.
    ## *return* :: allocated demands.
    def allocate(demandList, savList = nil)
      savList = @simulator.savList if(savList.nil?) ;

      allocateInit() ;
      
      if (demandList.size() > 0)
        demandList.each{|demand|
          allocateBySATforEachDemand(demand) ;
        }
      else
      #end

      demandList.each{|demand|
        allocateOne(demand, savList) ;
      }
      end
      allocateFinalize() ;

      return @allocatedList ;
    end
    
    
    # Anonymous1 12/27 ->
    #------------------------------------------
    #++
    ## allocate a demand to a certain sav.
    ## _demand_:: SavDemand.
    ## *return* :: allocated sav
    def allocateBySATforEachDemand(demand)
      selfDefnWeightsArray = Array.new();
      nofBus = @simulator.savList.size();
      acceptedSizeArray = Array.new();
      allPairsHashArray = Array.new();
      deadlineArray = Array.new();
      # Anonymous1 04/02 -> extension for the case of (one demand n-passengers) via 'pickDropArray'
      pickDropArray = Array.new();
      # Anonymous1 04/09 -> number of carried
      nofCarried = Array.new();
      newDemandSize = 1;
      capacityArray = Array.new();
      tmpArray = Array.new();
      tmpHash = Hash.new();
      # for dealing with the capacity's inconsistency of dummyPoint
      busIDArrayWhoseBusIncludeDummy = Array.new();
      @simulator.savList.each{|sav|
        #sav.clearDummyViaPointsInTail();
        if sav.viaPointList.size()-1 > sav.viaPointIndex && sav.viaPointList.size() >= 2
          for i in sav.viaPointIndex..sav.viaPointList.size()-2
            if sav.viaPointList[sav.viaPointIndex].mode != :dummy && sav.viaPointList[i].mode == :dummy
              puts "caught you!";
              sav.viaPointList.delete_at(i);
            end
          end
        end
        for i in sav.viaPointIndex..sav.viaPointList.size()-1
          if sav.viaPointList[i].mode == :dummy
            busIDArrayWhoseBusIncludeDummy.push(1);
            break;
          elsif i == sav.viaPointList.size()-1 && sav.viaPointList[i].mode != :dummy
            busIDArrayWhoseBusIncludeDummy.push(0);
          end
        end
        tmpArray.clear();
        tmpArray.push(sav.fetchPosition());
        acceptedSizeArray.push(sav.viaPointList.size()-sav.viaPointIndex);
        for i in sav.viaPointIndex..sav.viaPointList.size()-1
          tmpArray.push(sav.viaPointList[i]);
        end
        tmpHash.clear();
        for i in 1..tmpArray.size()-1
          if tmpArray[i].mode == :pickUp
            for j in i+1..tmpArray.size()-1
              if tmpArray[i].demand == tmpArray[j].demand && tmpArray[j].mode == :dropOff
                tmpHash.store(j-1, i-1);
                break;
              end
            end
          end
        end
        allPairsHashArray.push(tmpHash.clone());
        tmpArray.push(demand.tripViaPoint.pickUp);
        tmpArray.push(demand.tripViaPoint.dropOff);
        for i in 1..tmpArray.size()-1
          if tmpArray[i].mode == :dropOff
            deadlineArray.push((1*(tmpArray[i].demand.tripRequiredTime.dropOff)).to_i);
            pickDropArray.push((-1*(tmpArray[i].demand.numPassenger)).to_i);
          elsif tmpArray[i].mode == :pickUp
            deadlineArray.push(0);
            pickDropArray.push((1*(tmpArray[i].demand.numPassenger)).to_i);
          elsif tmpArray[i].mode == :dummy
            deadlineArray.push(0);
            pickDropArray.push(0);
          end
        end
        nofCarried.push(sav.countNumOnBoard());
        for i in 1..tmpArray.size()-1
          for j in 0..tmpArray.size()-1
            selfDefnWeightsArray.push((1+1*(estimateTime(tmpArray[j], tmpArray[i], sav, :averageManhattan))).to_i);
          end
        end
        capacityArray.push(sav.capacity);
        if sav.countNumOnBoard() > sav.capacity
          #puts "error numOnBorad: #{sav.countNumOnBoard()}";
          #exit;
        end
      }
      #puts "selfDefnWeightsArray: #{selfDefnWeightsArray}";
      #puts "nofBus: #{nofBus}";
      #puts "acceptedSizeArray: #{acceptedSizeArray}";
      #puts "allPairsHashArray: #{allPairsHashArray}";
      #puts "deadlineArray: #{deadlineArray}";
      #puts "pickDropArray: #{pickDropArray}";
      #puts "newDemandSize: #{newDemandSize}";
      #puts "capacityArray: #{capacityArray}";
      encodingDone = false;
      if (nofBus * newDemandSize != 0) 
        #wcnfGen(selfDefnWeightsArray, nofBus, acceptedSizeArray, allPairsHashArray, deadlineArray, newDemandSize, capacityArray);
        #runMaxSATSolver = "../../encodedProblem/qmaxsat_g3 -cpu-lim=10 -card=mrwto -pmodel=0 -incr=1 ../../encodedProblem/test.wcnf ../../encodedProblem/externality.txt ../../encodedProblem/answer.txt > ../../encodedProblem/log.txt";
        # for NCC
        encodingDone = wcnfGenNcc(selfDefnWeightsArray, nofBus, acceptedSizeArray, allPairsHashArray, deadlineArray, newDemandSize, capacityArray, busIDArrayWhoseBusIncludeDummy); # ,pickDropArray, nofCarried);
        runMaxSATSolver = "../../encodedProblem/qmaxsatNcc_g3 -cpu-lim=10 -card=mrwto -pmodel=0 -incr=1 ../../encodedProblem/test.wcnf ../../encodedProblem/externality.txt ../../encodedProblem/answer.txt > ../../encodedProblem/log.txt";
        clearPreviousAns = "rm ../../encodedProblem/answer.txt";
        if encodingDone 
          system(runMaxSATSolver);
        else
          system(clearPreviousAns);
        end
      end
      
      if encodingDone
        maxSATans = IO.readlines("../../encodedProblem/answer.txt");
      else
        maxSATans = Array.new();
        maxSATans.push("UNSAT");
        maxSATans.push("noEncodedProblem");
      end
      if encodingDone && maxSATans[0].include?("OPT") && maxSATans[1] != nil
        allocatedViaPointList = Array.new();
        tmpAnsReadLine = Array.new();
        busID = maxSATans[1].to_i;
        updateFlag = false;
        sav = @simulator.savList[busID-1];
        tmpAnsReadLine = maxSATans[2].split(" ").map{|str| str.to_i};
        if sav.viaPointIndex == sav.viaPointList.size()
          for i in 0..sav.viaPointList.size()-1
            allocatedViaPointList.push(sav.viaPointList[i]);
          end
          for i in 1..tmpAnsReadLine.size()-1
            updateFlag = true;
            if ( (tmpAnsReadLine[i]-(acceptedSizeArray[busID-1]))%2 == 0 ) # pickUp
              allocatedViaPointList.push( demand.tripViaPoint.pickUp );
            else # dropOff
              allocatedViaPointList.push( demand.tripViaPoint.dropOff );
            end
          end
        elsif acceptedSizeArray[busID-1]+1 < tmpAnsReadLine.size()
          for i in 0..sav.viaPointIndex
            allocatedViaPointList.push(sav.viaPointList[i]);
          end
          for i in 2..tmpAnsReadLine.size()-1
            updateFlag = true;
            if (tmpAnsReadLine[i] > acceptedSizeArray[busID-1]+1)
              if ( (tmpAnsReadLine[i]-(acceptedSizeArray[busID-1]+1))%2 == 1 ) # pickUp
                allocatedViaPointList.push( demand.tripViaPoint.pickUp );
              else # dropOff
                allocatedViaPointList.push( demand.tripViaPoint.dropOff );
              end
            else
              allocatedViaPointList.push(sav.viaPointList[ sav.viaPointIndex+tmpAnsReadLine[i]-2 ]);
            end
          end
        end
        if ( updateFlag )
          tmpViaPointIndex = sav.viaPointIndex;
          sav.viaPointList.clear();
          #for i in 0..allocatedViaPointList.size()-1
          #  sav.viaPointList.push(allocatedViaPointList[i]);
          #end
          for i in 0..allocatedViaPointList.size()-1
            if i <= tmpViaPointIndex || allocatedViaPointList[i].mode != :dummy
              sav.viaPointList.push(allocatedViaPointList[i]);
            else
              puts "planned route includes dummyViaPoint (NOT FIRST POINT)!";
            end
          end
          
          viaPointIndex = sav.viaPointIndex ;
          prevPos = sav.fetchPosition() ;
          currentTime = @simulator.currentTime ;
          (viaPointIndex...sav.viaPointList.size).each{|idx|
            viaPoint = sav.viaPointList[idx] ;
            diffTime = estimateTime(prevPos, viaPoint, sav, :averageManhattan) ;
            currentTime += diffTime ;

            # store new plan
            if(true) then
              if(viaPoint.mode == :pickUp) then
                viaPoint.demand.updatePlannedPickUpTime(currentTime) ;
              elsif(viaPoint.mode == :dropOff) then
                viaPoint.demand.updatePlannedDropOffTime(currentTime) ;
              end
            end

            prevPos = viaPoint.pos ;
          }
          
          sav.assignedDemandList.push(demand) ;
          sav.clearDummyViaPointsInTail();
          demand.sav = sav ;
          
          #@simulator.savList[busID-1] = sav;

          pushAllocatedDemand( demand ) ;
        end

      else #if maxSATans[0].include?("UNSAT") || !encodingDone
        if maxSATans[1] != nil
          if maxSATans[1].include?("exceeDeadline")
            puts "UNSAT (reason: exceeDeadline)";
            demand.cancel(@simulator, :exceedDropOffTime);
          elsif maxSATans[1].include?("exceedCapacity")
            puts "UNSAT (reason: exceedCapacity)";
            demand.cancel(@simulator, :exceedCapacity);
          elsif maxSATans[1].include?("noEncodedProblem")
            puts "UNSAT (reason: noEncodedProblem)";
            demand.cancel(@simulator, :notAssigned);
          else
            puts "UNSAT (reason: searchTimeout)";
            demand.cancel(@simulator, :notAssigned);
          end
        else
          puts "Unknown reason";
          demand.cancel(@simulator, :notAssigned);
          #exit;
        end
        pushCancelledDemand( demand ) ;
      end
      
      sumOFinished = 0;
      @simulator.savList.each{|sav|
        for i in 0..sav.viaPointIndex-1
          if sav.viaPointList[i] != nil && sav.viaPointList[i].mode == :dropOff
            sumOFinished += 1;
          end
        end
      }
      puts "sumOFinished : #{sumOFinished} | timeCost : #{@simulator.currentTime}";
      if @simulator.currentTime >= 44000
        puts "Finished time : #{@simulator.currentTime}";
        exit;
      end
      
    end
    # <- Anonymous1 12/27

    #------------------------------------------
    #++
    ## allocate a demand to a certain sav.
    ## _demand_:: SavDemand.
    ## *return* :: allocated sav
    def allocateOne(demand, savList)
      bestSav = nil ;
      bestTripIndex = nil ;
      bestAllocScore = nil ;
      violateReason = [] ;
      #counter = 0; # Anonymous1 20190114
      #bestSavIdx = 0; # Anonymous1 20190114
      start_time = Time.now();

      savList.each{|sav|
        savViolateReason = [] ;
        currentIndex = sav.viaPointIndex ;
        maxIndex = sav.viaPointList.size() ;
        (currentIndex..maxIndex).each{ |i|
          pickUpIndex = i - currentIndex ;
          (i..maxIndex).each{ |j|
            dropOffIndex = j - currentIndex ;
            tripIndex = Trip.new(pickUpIndex, dropOffIndex) ;
            allocScore =
              estimateTimeForNewRoute(sav, demand, tripIndex, false) ;

            ## collect violate reason
            if(allocScore[:violateReason].nil?) then
              savViolateReason = nil ;
            elsif(!savViolateReason.nil?) then
              reason = allocScore[:violateReason] ;
              if(!savViolateReason.include?(reason)) then
                savViolateReason.push(reason)
              end
            end
            
            if(compareScore(bestAllocScore, allocScore)) then
              #bestSavIdx = counter; # Anonymous1 20190114
              bestSav = sav ;
              bestTripIndex = tripIndex ;
              bestAllocScore = allocScore ;
            end
          }
        }
        if(savViolateReason) then
          savViolateReason.each{|reason|
            violateReason.push(reason) if(!violateReason.include?(reason));
          }
        end
        
        #counter += 1; # Anonymous1 20190114
        if Time.now() - start_time >= 10
          break;
        end
      }
      
      allocateDemandToSav(demand, bestSav, bestTripIndex, violateReason) ;
      
      # Anonymous1 20190128
      nofMax = 65534;
      nofInst = 1;
      for i in 2..nofMax+1
        if File.exist?("../../expDir/seqOpTime/test_#{nofInst}.time")
          if i == nofMax+1
            exit
          end
          nofInst = i;
        end
      end
      timeFile = File.new("../../expDir/seqOpTime/test_#{nofInst}.time", "w+");
      timeFile.syswrite("seqOpTime #{nofInst} : #{Time.now() - start_time}");
      
      sumOFinished = 0;
      @simulator.savList.each{|sav|
        for i in 0..sav.viaPointIndex-1
          if sav.viaPointList[i] != nil && sav.viaPointList[i].mode == :dropOff
            sumOFinished += 1;
          end
        end
      }
      puts "sumOFinished : #{sumOFinished} | timeCost : #{@simulator.currentTime}";
      if @simulator.currentTime >= 44000
        puts "Finished time : #{@simulator.currentTime}";
        exit;
      end
      
      return bestSav ;
    end

    #------------------------------------------
    #++
    ## compare allocation score.
    ## _oldScore_:: old best score. nil if no best.
    ## _newScore_:: new score.
    ## *return* :: true when the old best should be replaced.
    def compareScore(oldScore, newScore)
      if(!newScore[:violateReason].nil?) then
        return false ;
      elsif(oldScore.nil?) then
        return true ;
      elsif(oldScore[:sumDelay] > newScore[:sumDelay]) then
        return true ;
      else
        return false ;
      end
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandSeqOpt
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavBase < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleDirBase = "/home/noda/work/iss/SAVS/Data" ;
    SampleDir = "#{SampleDirBase}/2018.0104.Tsukuba"
    SampleConfFile03 = "#{SampleDir}/tsukuba.03.sumocfg" ;

    SampleXmlMapFile = "#{SampleDir}/TsukubaCentral.small.net.xml" ;
    SampleJsonMapFile = SampleXmlMapFile.gsub(/.xml$/,".json") ;

    #----------------------------------------------------
    #++
    ## show separator and title of the test.
    def setup
#      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      name = "#{(@method_name||@__name__)}(#{self.class.name})" ;
      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      super
    end

    #----------------------------------------------------
    #++
    ## about test_a
    def test_a
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
