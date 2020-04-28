#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Allocator (abstracted base class)
## Author:: Anonymous3
## Version:: 0.0 2018/01/28 Anonymous3
##
## === History
## * [2018/01/28]: Create This File.
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
require 'WithConfParam.rb' ;

require 'SavSimulator.rb' ;
require 'SavDemand.rb' ;
require 'SavVehicle.rb' ;
require 'SavTrip.rb' ;
require 'SavUtil.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Sav Allocator
  class SavAllocator < WithConfParam
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {} ;
    
    ## SubClass Table
    SubClassTable = {} ;

    #--============================================================
    #--------------------------------------------------------------
    #++
    ## サブクラスの登録
    ## _typeName_: サブクラスを指定する allocMode の名前。
    ## _klass_: そのクラス。
    def self.registerSubClass(typeName, klass)
      SubClassTable[typeName] = klass ;
    end

    #--============================================================
    #--------------------------------------------------------------
    #++
    ## allocMode によるサブクラスの取得。
    ## _mode_: typeName もしくは :allocMode エントリを含む Hash。
    ## *return*: サブクラス。
    def self.getSubClassByType(mode)
      typeName = ((mode.is_a?(Hash)) ? mode[:allocMode] : mode) ;
      klass = SubClassTable[typeName] ;

      if(klass.nil?) then
        p [:getSubClassByType, :mode, mode, typeName] ;
        pp [:knownClass, SubClassTable] ;
        raise "unknown mode for SavAlloc sub-class." ;
      end
      
      return klass ;
    end
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## link to SavSimulator
    attr_accessor :simulator ;
    ## list of allocated demands.  should be reset every allocate().
    attr_accessor :allocatedList ;
    ## list of cancelled demands.  should be reset every allocate().
    attr_accessor :cancelledList ;
    ## list of allocated demands.  for logging
    attr_accessor :allocatedListAccumulated ;
    ## list of cancelled demands.  for logging
    attr_accessor :cancelledListAccumulated ;
    
    #------------------------------------------
    #++
    ## initialize
    ## _savSim_ :: parent simulator
    ## _conf_:: configuration information
    def initialize(savSim, conf = {})
      @simulator = savSim ;
      super(conf) ;
      setup() ;
    end

    #------------------------------------------
    #++
    ## setup.
    ## should be re-defined in subclass if needed.
    def setup() 
      @allocatedList = [] ;
      @cancelledList = [] ;
      @allocatedListAccumulated = [] ;
      @cancelledListAccumulated = [] ;
    end
    
    #------------------------------------------
    #++
    ## allocate
    ## actual allocation should be done in this method.
    ## _demandList_:: list of SavDemand.
    ## *return* :: allocated demands.
    def allocate(demandList)
      raise "allocate() should be defined in class :#{self.class}."
    end

    #------------------------------------------
    #++
    ## initialize step of allocate
    def allocateInit()
      @allocatedList.clear() ;
      @cancelledList.clear() ;
    end

    #------------------------------------------
    #++
    ## final step of allocate
    def allocateFinalize()
      @allocatedListAccumulated.concat(@allocatedList)
      @cancelledListAccumulated.concat(@cancelledList)
    end

    #------------------------------------------
    #++
    ## push allocated demand to the result list.
    def pushAllocatedDemand(demand)
      @allocatedList.push(demand) ;
    end
      
    #------------------------------------------
    #++
    ## push canceled demand to the result list.
    def pushCancelledDemand(demand)
      @cancelledList.push(demand) ;
    end
      
    #------------------------------------------
    #++
    ## allocate a demand to a sav.
    ## if the sav is nil, then, cancel the demand.
    ## _demand_ :: a SavDemand to allocate.
    ## _sav_ :: a SavVehicle to allocate the demand to.
    ##          If nil, cancel the demand.
    ## _tripIndex_ :: index pair of pickUp and dropOff.
    ## _mode_ :: the mode to estimate the time and distance.
    def allocateDemandToSav(demand, sav, tripIndex,
                            cancelReason = [], mode = :averageManhattan)
      if(!sav.nil?) then
        estimateTimeForNewRoute(sav, demand, tripIndex, true, mode) ;
        sav.assignDemand(demand, tripIndex.pickUp, tripIndex.dropOff) ;
        pushAllocatedDemand(demand) ;
      else
        logging(:info, "cancel:" + demand.id + "/" + cancelReason.join(",")) ;
        demand.cancel(@simulator, cancelReason) ;
        pushCancelledDemand(demand) ;
      end
    end

    #------------------------------------------
    #++
    ## estimate time for whole of a SAV route with new demands 
    ## _sav_ : vehicle to use.
    ## _demand_ : new demand.
    ## _tripIndex_ : index in route to insert pickUp/dropOff ViaPoints.
    ## _storeNewPlanP_ : if true, store new planned time to each ViaPoints.
    ## _mode_ : specify estimation mode.
    ## *return*:{:sumDelay => sumOfDelay, # total delay from planned time.
    ##           :demandTripPlan => tripTime, #planned time for the new demand.
    ##           :violateReason => something, # non-nil when new demand violate others.
    ##           }
    def estimateTimeForNewRoute(sav, demand, tripIndex,
                                storeNewPlanP = false,
                                mode = :averageManhattan)
      viaPointIndex = sav.viaPointIndex ;
      pickUpIndex = (tripIndex.pickUp < 0 ?
                       sav.viaPointList.size + 1 + tripIndex.pickUp :
                       tripIndex.pickUp + viaPointIndex) ;
      dropOffIndex = (tripIndex.dropOff < 0 ?
                        sav.viaPointList.size + 1 + tripIndex.dropOff :
                        tripIndex.dropOff + viaPointIndex) ;
      insertIndex = [ pickUpIndex, dropOffIndex ] ;
      
      insertObject = [demand.tripViaPoint.pickUp,
                      demand.tripViaPoint.dropOff] ;
      route = TentativeArray.new(sav.viaPointList, insertIndex, insertObject) ;

      return estimateTimeForNewRouteBody(sav, route, 
                                         storeNewPlanP, mode) ;
    end

    #------------------------------------------
    #++
    ## estimate time for whole of a SAV route with new demands  (body)
    def estimateTimeForNewRouteBody(sav, route, 
                                    storeNewPlanP = false,
                                    mode = :averageManhattan)
      violateReason = nil ;
      sumDelay = 0.0 ;
      demandTripPlan = Trip.new(nil,nil) ;

      viaPointIndex = sav.viaPointIndex ;
      prevPos = sav.fetchPosition() ;
      currentTime = @simulator.currentTime ;

      nPass = sav.countNumOnBoard() ; 
      
      (viaPointIndex...route.size).each{|idx|
        viaPoint = route[idx] ;
        diffTime = estimateTime(prevPos, viaPoint, sav, mode) ;
        currentTime += diffTime ;

        # set trip plan or calc delay.
        if(idx == route.kthIndex(0)) then ## pickUp index for new demand
          nPass += 1 ;
          demandTripPlan.pickUp = currentTime ;
        elsif(idx == route.kthIndex(1)) then ## dropOff index for new demand
          nPass -= 1 ;
          demandTripPlan.dropOff = currentTime ;
        else # for old demands
          delay = 0.0 ;
          if(viaPoint.mode == :pickUp) then
            nPass += 1 ;
            if(viaPoint.demand.getTripPlannedTime &&
               viaPoint.demand.getTripPlannedTime.pickUp) then
              delay = currentTime - viaPoint.demand.getTripPlannedTime.pickUp ;
            else
              logging(:warn,
                      "planned time for pickUp is not set.",
                      ("\tdemand=" + viaPoint.demand.id),
                      ("\ttripTime=" +
                       viaPoint.demand.getTripPlannedTime.inspect)) ;
            end
          elsif(viaPoint.mode == :dropOff) then
            nPass -= 1 ;
            if(viaPoint.demand.getTripPlannedTime &&
               viaPoint.demand.getTripPlannedTime.dropOff) then
              delay = currentTime - viaPoint.demand.getTripPlannedTime.dropOff ;
            else
              logging(:warn,
                      "planned time for dropOff is not set.",
                      ("\tdemand=" + viaPoint.demand.id),
                      ("\ttripTime=" +
                       viaPoint.demand.getTripPlannedTime.inspect)) ;
            end
          end
          
          # sum-up delay
          sumDelay += delay if (delay > 0.0) ;
        end

        # check dropOff deadline
        if(viaPoint.mode == :dropOff &&
           viaPoint.demand.tripRequiredTime.dropOff &&
           currentTime > viaPoint.demand.tripRequiredTime.dropOff) then
          violateReason = :exceedDropOffTime ;
          break ; # exit from loop
        end
        
        # check capacity
        if(nPass > sav.capacity) then
          violateReason = :exceedCapacity ;
          break ;
        end

        # store new plan
        if(storeNewPlanP) then
          if(viaPoint.mode == :pickUp) then
            viaPoint.demand.updatePlannedPickUpTime(currentTime) ;
          elsif(viaPoint.mode == :dropOff) then
            viaPoint.demand.updatePlannedDropOffTime(currentTime) ;
          end
        end
              
        prevPos = viaPoint.pos ;
      }

      ## add travel time for the new demand

      if(!violateReason.nil?) then
        return { :violateReason => violateReason }
      else
        sumDelay += demandTripPlan.dropOff - @simulator.currentTime ;
        return { :sumDelay => sumDelay,
                 :demandTripPlan => demandTripPlan } ;
      end
    end
    
    #------------------------------------------
    #++
    ## estimate time. 
    ## _from_, _to_ : two ViaPoint or Geo2D::Vector
    ## _sav_ : vehicle to use.
    ## _mode_ : specify estimation mode.
    def estimateTime(from, to, sav, mode = :averageManhattan)
      distance = estimateDistance(from, to, mode) ;
      speed = sav.averageSpeed ;
      time = distance / speed ;

      ## add SavViaPoint stop duration.
      time += to.duration if(to.is_a?(Sav::ViaPoint)) ;

      return time ;
    end
    
    #------------------------------------------
    #++
    ## estimate distance between two viaPoint
    ## _from_, _to_ : two ViaPoint or Geo2D::Vector
    ## _mode_ : specify estimation mode.
    def estimateDistance(from, to, mode = :averageManhattan)
      if(from.is_a?(Sav::ViaPoint)) then
        return estimateDistance(from.pos, to, mode) ;
      elsif(to.is_a?(Sav::ViaPoint)) then
        return estimateDistance(from, to.pos, mode) ;
      else
        return estimateDistanceBody(from, to, mode) ;
      end
    end
    
    #------------------------------------------
    #++
    ## estimate distance between two position.
    ## _fromPos_, _toPos_ : two pos.
    ## _mode_ : specify estimation mode.
    def estimateDistanceBody(fromPos, toPos, mode = :averageManhattan)
      case(mode)
      when :averageManhattan ;
        return estimateDistanceBetweenPos_averageManhattan(fromPos, toPos) ;
      else
        raise "unknown estimation mode:" + mode ;
      end
    end
      
    #------------------------------------------
    #++
    ## estimate distance between two position. (average Manhattan distance)
    ## _fromPos_, _toPos_ : two pos.  should be an instance of Geo2D::Vector.
    def estimateDistanceBetweenPos_averageManhattan(fromPos, toPos)
      return Sav::Util.averageManhattanDistance(fromPos, toPos) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## add sav vehicle and assign to a sav base
    ## _savBase_:: sav base
    ## *return*:: new sav
    def addNewSavVehicleToBase(savBase = nil)
      savBase = @simulator.savBaseList.sample if(savBase.nil?) ;

      newSav = savBase.addNewSavVehicle() ;

      return newSav ;
    end

    #--------------------------------
    #++
    ## get max number of sav. (used only for guild)
    def nSavMax()
      return 0 ;
    end

    #--------------------------------------------------------------
    #++
    ## dump log to a stream.
    ## _strm_: stream to dump.
    def dumpLogToStream(strm)
      strm << JSON.generate(dumpLogJson()) << "\n" ;
    end

    #--------------------------------------------------------------
    #++
    ## dump log in json object.
    def dumpLogJson(baseJson = {})
      _allocJson = [] ;
      @allocatedListAccumulated.each{|demand|
        _demandJson = ({ :id => demand.id }) ;
        _allocJson.push(_demandJson) ;
      }
      _cancelJson = [] ;
      @cancelledListAccumulated.each{|demand|
        _demandJson = ({ :id => demand.id }) ;
        _cancelJson.push(_demandJson) ;
      }
      json = baseJson.dup.update({ :allocatedList => _allocJson,
                                   :cancelledList => _cancelJson }) ;
      return json ;
    end
    
    #--------------------------------
    #++
    ## logging
    def logging(level, *messageList, &body)
      @simulator.logging(level, *messageList, &body) ;
    end

    #------------------------------------------
    #++
    ## for inspect()
    alias inspect_original inspect ;
    def inspect() ;
      dummy = self.dup ;
      dummy.simulator = nil ;
      return dummy.inspect_original ;
    end
    
    #--============================================================
    #--------------------------------------------------------------
    #++
    ## newAllocatorByConf
    ## _mode_: typeName もしくは :allocMode エントリを含む Hash。
    ## *return*: サブクラス。
    def self.newAllocatorByConf(simulator, klass, conf)
      # specify class for allocator.
      klass = conf[:type] if(klass.nil?()) ;

      if(!klass.is_a?(Class)) then
        klass = 
          self.getSubClassByType(klass) ;
        if(klass.nil?) then
          raise "unknown allocator class: #{klass.inspect}" ;
        end
      end

      return klass.new(simulator, conf) ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

    #--========================================
    #--::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #------------------------------------------

  end # class SavAllocator
  
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
