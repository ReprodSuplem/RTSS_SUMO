#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Vehicle
## Author:: Anonymous3
## Version:: 0.0 2018/01/23 Anonymous3
##
## === History
## * [2018/01/23]: Create This File.
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

require 'TraciVehicle.rb' ;
require 'SavViaPoint.rb' ;
require 'SavDemand.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--======================================================================
  #++
  ## Sav Vehicle
  class SavVehicle < Sumo::Traci::Vehicle
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = ({ # 平均速度
                     :averageSpeed => 30.0 * 1000 / 60 / 60,
                     # 乗客定員
                     :capacity => 4,
                     # 徘徊時の u-tern 停止時間
                     :roamingStopDuration => 1,
                     # 徘徊時に待機場所に戻る際の不感マージン
                     :homingMargin => 1000.0,
                     # 徘徊時に待機場所に戻る際の不感マージン
                     :homingProb => 0.1,
                     # SavBase を最終待機場所とする時の漸近割合
                     :segmentRatioToBase => 0.5,
                     nil => nil }) ;

    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## viaPointList
    attr_accessor :viaPointList ;
    ## viaPoint Index
    attr_accessor :viaPointIndex ;
    ## link to SavBase
    attr_accessor :base ;
    ## average speed
    attr_accessor :averageSpeed ;
    ## capacity (maximum number of passengers)
    attr_accessor :capacity ;
    ## the list of on-board demands
    attr_accessor :onBoardList ;
    ## the list of assigned demands
    attr_accessor :assignedDemandList ;
    
    ## arrived ViaPoint in a cycle.
    attr_accessor :arrivedViaPoint ;

    ## viaPoint to be submitted to SUMO
    attr_accessor :submittedViaPoint ;
    
    #--------------------------------------------------------------
    #++
    ## description of method initialize
    ## _conf_:: configulation
    def initialize(manager, id = nil, conf = {})
      super(manager, id, conf) ;
      @base = getConf(:base) ;
      setViaPointList([]) ;
      @averageSpeed = getConf(:averageSpeed) ;
      @capacity = getConf(:capacity) ;
      @onBoardList = [] ;
      @assignedDemandList = [] ;
    end


    #--------------------------------------------------------------
    #++
    ## get simulator
    def getSavSimulator()
      @base.simulator ;
    end
    
    #--------------------------------------------------------------
    #++
    ## set viaPointList
    ## _conf_:: configulation
    def setViaPointList(list, index = 0)
      @viaPointList = list ;
      @viaPointIndex = index ;
    end

    #--------------------------------------------------------------
    #++
    ## get next viaPoint
    def extractRemainViaPoints()
      if(remainViaPointN() <= 0) then
        return [] ;
      else
        return @viaPointList[@viaPointIndex..-1] ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## get next viaPoint
    def nextViaPoint()
      if(remainViaPointN() <= 0) then
        return nil ;
      else
        return @viaPointList[@viaPointIndex] ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## get next viaPoint
    def remainViaPointN()
      return @viaPointList.length - @viaPointIndex ;
    end

    #--------------------------------------------------------------
    #++
    ## shift ViaPointList
    def shiftViaPoint()
      @viaPointIndex += 1 ;
      
      if(@viaPointIndex > @viaPointList.size) then
        @viaPointIndex = @viaPointList.size ;
      end
        
      return nextViaPoint() ;
    end

    #--------------------------------------------------------------
    #++
    ## shift ViaPointList and ensure necessity of U-Turn.
    def shiftViaPointEnsure()
      shiftViaPoint() ;
      if(!doesArriveAtNextViaPoint() && checkNextViaPointIsBehind()) then
        logging(:info, "Need U-turn toward:"){ nextViaPoint().getLocation() } 
        insertUTurnViaPoint() ;
      end
      return nextViaPoint() ;
    end

    #--------------------------------------------------------------
    #++
    ## skip the next viaPoint.
    ## _reason_ :: reason to skip.
    ## *return* :: next via point.
    def skipViaPointBecause(reason)
      sim = getSavSimulator() ;
      viaPoint = nextViaPoint() ;
      viaPoint.letSkipped(sim.currentTime(), reason) ;
      viaPoint.clearPoi(sim) ;
      
      return shiftViaPoint() ;
    end

    #--------------------------------------------------------------
    #++
    ## insert ViaPoint at the nth from the current ViaPoint.
    def insertViaPoint(viaPoint, nth = 0)
      if(nth < 0) then
        if(@viaPointList.size + nth + 1 < @viaPointIndex) ; then
          nth = @viaPointIndex - @viaPointList.size - 1;
        end
        @viaPointList.insert(nth, viaPoint) ;
      else
        if(@viaPointIndex + nth > @viaPointList.size) then
          nth = @viaPointList.size - @viaPointIndex ;
        end
        @viaPointList.insert(@viaPointIndex + nth, viaPoint) ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## insert ViaPoint at the nth from the current ViaPoint.
    def insertViaPointLast(viaPoint)
      insertViaPoint(viaPoint, -1) ;
    end

    #--------------------------------------------------------------
    #++
    ## insert dummy ViaPoint
    def insertDummyViaPointByPos(pos, duration = 0, nth = 0)
      viaPoint = ViaPoint.new(pos, nil, :dummy, duration,
                              getSavSimulator()) ;
      insertViaPoint(viaPoint, nth) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## insert dummy ViaPoint
    def insertUTurnViaPoint(stopDuration = 0, location = nil)
      sim = getSavSimulator() ;
      location = fetchLocation() if(location.nil?) ;
      edge = sim.map.edgeTable[location.edge] ;
      
      if(edge.nil?) then
        _pos = fetchPosition() ;
        edge = sim.map.findNearestEdgeFrom(_pos) ;
        logging(:warn,
                "location edge is not in the map database.",
                " savId=#{@id}.",
                " location=#{location.inspect}.",
                " pos=#{_pos}.",
                " newEdge=#{edge.inspect}.") ;
      end
      
      pos = edge.getPointForUTurn(sim.map) ;
      insertDummyViaPointByPos(pos, stopDuration) ;
    end

    #--------------------------------------------------------------
    #++
    ## check to arrive at the next viaPoint
    ## *return* :: false if all viaPoint is arrived.
    def roamAround()
      fetchPosition() ;
      
      if(shouldHoming()) then
        _targetPos = getTentativeStandByPosition(@pos);
        insertDummyViaPointByPos(_targetPos) ;
      else
        insertUTurnViaPoint(getConf(:roamingStopDuration)) ;
      end
      
      setNextViaPointAsTarget() ;      
    end

    #--------------------------------------------------------------
    #++
    ## check homing action is needed.
    ## *return* :: true if homeing is required.
    def shouldHoming()
      _dist = @pos.distanceTo(getStandByPosition()) ;

      return (_dist > getConf(:homingMargin) &&
              rand() < getConf(:homingProb)) ;
    end

    #--------------------------------------------------------------
    #++
    ## final stand-by position.
    ## *return* :: position
    def getStandByPosition()
      ## もし、架空の待機場所などを与える場合、ここに追加。
      return @base.position ;
    end
    
    #--------------------------------------------------------------
    #++
    ## tentative stand-by position.
    ## by default, return the mid-point to the Sav Base.
    ## _pos_ :: current position.
    ## _ratio_:: SavBase を最終待機場所とする時の漸近割合
    ## *return* :: position
    def getTentativeStandByPosition(_pos = nil)
      ## SavBase へ漸近的に近づく。
      _pos = fetchPosition() if(_pos.nil?) ;
      finalPos = getStandByPosition() ;
      targetLine = Geo2D::LineSegment.new(_pos,finalPos) ;
      ratio = getConf(:segmentRatioToBase) ;
      targetPos = targetLine.segmentPoint(ratio) ;

      return targetPos ;
    end

    #--------------------------------------------------------------
    #++
    ## clear dummy ViaPoint in tails.
    def clearDummyViaPointsInTail()
      dummyTail = true ;
      while(dummyTail)
        if(@viaPointList.size <= @viaPointIndex ||
           @viaPointList.last.mode != :dummy) then
          dummyTail = false ;
        else
          dummyVia = @viaPointList.pop ;
          dummyVia.clearPoi(getSavSimulator()) ;
        end
      end
    end
    
    #--------------------------------------------------------------
    #++
    ## check next ViaPoint is behind.
    def checkNextViaPointIsBehind(location = nil)
      location = fetchLocation() if(location.nil?) ;
      viaPoint = nextViaPoint() ;

      if(viaPoint.nil?) then
        return false ;
      else
        return location.isAheadOf(viaPoint.getLocation()) ;
      end
    end
    
    #--------------------------------------------------------------
    #++
    ## check to arrive at the next viaPoint.
    ## If the next ViaPoint is nil (empty target), consider to be arrived.
    def doesArriveAtNextViaPoint()
      viaPoint = nextViaPoint() ;
      return true if(viaPoint.nil?) ;
      
      if(isStopped()) then
        location = fetchLocation() ;
        viaLocation = viaPoint.getLocation() ;
        if(location.isCloseEnough(viaLocation,false,
                                  getSavSimulator().stopMargin)) then
          return true ;
        else
          return false ;
        end
      else
        return false ;
      end
    end
    
    #--------------------------------------------------------------
    #++
    ## check to arrive at the next viaPoint
    ## *return* :: false if all viaPoint is arrived.
    def setNextViaPointAsTarget()
      viaPoint = nextViaPoint() ;
      return false if(viaPoint.nil?);

      duration = viaPoint.duration ;
      viaEdge = viaPoint.getEdge()
      if(submitChangeTarget(viaEdge.id)) then
        begin ## succeed to set the next viaPoint to the target.
          submitStop(viaEdge.id, viaPoint.getSpan(), 0, duration) ;
          @submittedNextViaPoint = viaPoint ;
          return true ;
        rescue Sumo::SumoException => ex
          logging(:warn,
                  "sav(id=#{@id}) can not stop at:#{viaEdge.id}.") ;
          skipViaPointBecause("can not stop.") ;
          return setNextViaPointAsTarget() ;
        end
      else ## if fail to submit viaEdge, skip the viaPoint.
        logging(:warn,
                "sav(id=#{@id}) can not change target to:#{viaEdge.id}.") ;
        skipViaPointBecause("can not change target.") ;
        return setNextViaPointAsTarget() ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## assign Demand at a specific position
    ## _demand_:: a demand to assign.
    ## _pickUpIndex_:: insert position in ViaPoint for pick-up.
    ## _dropOffIndex_:: insert position in ViaPoint for drop-off.
    def assignDemand(demand, pickUpIndex = -1, dropOffIndex = -1)
      @assignedDemandList.push(demand) ;

      self.insertViaPoint(demand.tripViaPoint.dropOff, dropOffIndex) ;

      ## adjust pickUpIndex if negative.
      if(pickUpIndex < 0 && dropOffIndex <= pickUpIndex) then
        pickUpIndex -= 1 ;
      end
      
      self.insertViaPoint(demand.tripViaPoint.pickUp, pickUpIndex) ;

      self.clearDummyViaPointsInTail() ;

      demand.sav = self ;

      return demand ;
    end
    
    #--------------------------------------------------------------
    #++
    ## check to arrive at the next viaPoint
    ## *return* :: false if all viaPoint is arrived.
    def cycleCheckViaPoint()
      @arrivedViaPoint = nil ;
      @newTargetP = false ;

      if(doesArriveAtNextViaPoint()) then
        @arrivedViaPoint = nextViaPoint() ;
        if(!@arrivedViaPoint.nil?) then
          sim = getSavSimulator() ;
          @arrivedViaPoint.arrivedAt(sim) ;
          @arrivedViaPoint.clearPoi(sim) ;
          adjustOnBoardListByViaPoint(@arrivedViaPoint) ;
        end
        
        shiftViaPointEnsure() ;
        @newTargetP = true ;

#        p [:arrived, @arrivedViaPoint.mode, @onBoardList.size, countNumOnBoard()] ;
        
        return true ;
      else
        return false ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## check to arrive at the next viaPoint
    ## *return* :: false if all viaPoint is arrived.
    def doesProceedDemand()
      return (@arrivedViaPoint && @arrivedViaPoint.hasDemand()) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## manipulate onboard demands (add)
    def addDemandToOnBoard(demand)
      demand.joinToOnBoardList(@onBoardList) ;
      @onBoardList.push(demand) ;
    end

    #--------------------------------------------------------------
    #++
    ## manipulate onboard demands (remove)
    def dropDemandFromOnBoard(demand)
      @onBoardList.delete(demand) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## manipulate onboard demands using ViaPoint info.
    def adjustOnBoardListByViaPoint(viaPoint)
      case(viaPoint.mode)
      when :pickUp ;
        if(viaPoint.demand.nil?) then
          raise "viaPoint should have a demand:" + viaPoint.inspect ;
        end
        addDemandToOnBoard(viaPoint.demand) ;
      when :dropOff ;
        if(viaPoint.demand.nil?) then
          raise "viaPoint should have a demand:" + viaPoint.inspect ;
        end
        dropDemandFromOnBoard(viaPoint.demand) ;
      end
    end
    
    #--------------------------------------------------------------
    #++
    ## count number of passenger on board
    def countNumOnBoard()
      count = 0 ;
      @onBoardList.each{|demand|
        count += demand.numPassenger ;
      }
      return count ;
    end
    
    #--------------------------------------------------------------
    #++
    ## set next via point as target when new target should be set.
    ## *return* :: false if all viaPoint is arrived.
    def cycleRenewTargetIfNeed()
      if(false)
      if(hasNoDemands() && remainViaPointN() > 0) then
        viaPoint = nextViaPoint() ;
        distToBase = viaPoint.pos.distanceTo(@base.position) ;
        if(distToBase > 1000 && rand(10) == 0) then
          skipViaPointBecause("for roaming");
          @newTargetP = true ;
          p [:skipToRoam, @id, distToBase]
        end
      end
      end

      ## check submittedViaPoint is same as nextViaPoint() ;
      if(!@submittedViaPoint.nil? &&
         (@submittedViaPoint != nextViaPoint())) then
        p [:viaPoint_Different] ;
        @newTargetP = true ;
      end
      
      if(@newTargetP) then
        r = setNextViaPointAsTarget() ;
        roamAround() if(!r) ; ## keep stay here if no next via point.
      end
    end

    #--------------------------------------------------------------
    #++
    ## check all remain ViaPoints are dummy.
    ## This is for checking the vehicle is roaming mode,
    ## *return* :: true if all remain ViaPoints are dummy.
    def hasNoDemands()
      hasDemandP = false ;
      (@viaPointIndex...@viaPointList.size).each{|index|
        hasDemandP = true if (!@viaPointList[index].isDummy()) ;
      }
      return !hasDemandP ;
    end
    
    #--------------------------------------------------------------
    #++
    ## count numOnBoard
    def numOnBoard()
      sum = 0 ;
      ###########
    end
    
    #--------------------------------------------------------------
    #++
    ## renew ID
    def renewId()
      oldId = @id ;
      super() ;
      @base.savTable.delete(oldId) ;
      @base.savTable[@id] = self ;
    end

    #--------------------------------------------------------------
    #++
    ## trail JSON
    def trailJson()
      json = {} ;
      json['id'] = @id ;
      json['base'] = @base.name ;
      json['capacity'] = @capacity ;
      json['viaPointIndex'] = @viaPointIndex ;
      json['viaPointList'] =
        (@viaPointList.map{|via|
           { 'pos' => via.pos.toJson(),
             'demandId' => (via.demand ? via.demand.id : nil),
             'mode' => via.mode.to_s,
             'duration' => via.duration,
             'time' => via.time } ;}) ;
      json['onBoardList'] = @onBoardList.map{|demand| demand.id} ;
      json['assignedDemandList'] =
        (@assignedDemandList.map{|demand|
           { 'id' => demand.id,
             'passenger' => demand.passenger,
             'numPassenger' => demand.numPassenger,
             'tripPos' => demand.tripPos.toJson(),
             'arisedTime' => demand.arisedTime,
             'tripRequiredTime' => demand.tripRequiredTime.toJson(),
             'tripTime' => demand.getTripTime().toJson(),
           }}) ;
      return json ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavVehicle
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavVehicle < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    TestData = nil ;

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
      pp [:test_a] ;
      assert_equal("foo-",:foo.to_s) ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
